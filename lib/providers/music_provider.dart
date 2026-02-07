import 'package:audio_session/audio_session.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

// Import kept to prevent build errors, but we won't use the client for now.
import 'package:oxcy/clients.dart'; 

class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;

  Song({
    required this.id, 
    required this.title, 
    required this.artist, 
    required this.thumbUrl,
    this.type = 'video',
  });
}

class MusicProvider with ChangeNotifier {
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  // 1. Standard Init
  final _yt = yt.YoutubeExplode();
  
  final _player = AudioPlayer();
  
  List<Song> _searchResults = []; 
  List<Song> _queue = [];         
  int _currentIndex = -1;
  
  String? _nextPageToken;
  String _currentQuery = "";
  bool _isFetchingMore = false;
  
  bool _isLoadingSong = false;
  String? _errorMessage;
  
  bool _isMiniPlayerVisible = false;
  bool _isPlayerExpanded = false;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;

  // Getters
  AudioPlayer get player => _player;
  List<Song> get searchResults => _searchResults;
  List<Song> get queue => _queue;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isShuffling => _isShuffling;
  LoopMode get loopMode => _loopMode;
  bool get isFetchingMore => _isFetchingMore;
  bool get isLoadingSong => _isLoadingSong;
  String? get errorMessage => _errorMessage;

  MusicProvider() {
    _initAudioSession();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _player.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
    );
  }

  Future<void> search(String query) async {
    _currentQuery = query;
    _searchResults = [];
    _nextPageToken = null;
    notifyListeners();
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || _nextPageToken == null) return;
    _isFetchingMore = true;
    notifyListeners();
    await _fetchPage();
    _isFetchingMore = false;
    notifyListeners();
  }

  Future<void> _fetchPage() async {
    try {
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$_currentQuery&type=video,playlist&maxResults=20&key=$_apiKey';
      if (_nextPageToken != null) url += "&pageToken=$_nextPageToken";

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _nextPageToken = data['nextPageToken']; 
        List<dynamic> items = data['items'];
        
        List<Song> newResults = items.map((item) {
           var thumbs = item['snippet']['thumbnails'];
           String img = thumbs['high']['url'];
           if (thumbs.containsKey('maxres')) img = thumbs['maxres']['url'];

           String id = item['id']['videoId'] ?? item['id']['playlistId'];
           String kind = item['id']['kind'] == "youtube#playlist" ? 'playlist' : 'video';

          return Song(
            id: id,
            title: item['snippet']['title'],
            artist: item['snippet']['channelTitle'],
            thumbUrl: img,
            type: kind,
          );
        }).toList();
        
        _searchResults.addAll(newResults);
        notifyListeners();
      }
    } catch (e) {
      print("Network Error: $e");
    }
  }

  Future<void> play(Song song) async {
    await _player.stop();
    _queue = [song];
    _currentIndex = 0;
    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    _errorMessage = null; 
    await _loadAndPlay();
  }

  Future<void> playPlaylist(Song album) async {
    await _player.stop();
    _isMiniPlayerVisible = true;
    _isLoadingSong = true; 
    notifyListeners();
    
    try {
      var playlist = await _yt.playlists.get(yt.PlaylistId(album.id));
      var videos = _yt.playlists.getVideos(playlist.id);
      
      List<Song> albumSongs = [];
      await for (var video in videos) {
        albumSongs.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          thumbUrl: video.thumbnails.highResUrl,
          type: 'video',
        ));
        if (albumSongs.length >= 50) break; 
      }

      if (albumSongs.isNotEmpty) {
        _queue = albumSongs;
        _currentIndex = 0;
        _isPlayerExpanded = true;
        await _loadAndPlay();
      } else {
        _isLoadingSong = false;
        notifyListeners();
      }
    } catch (e) {
      _isLoadingSong = false;
      _errorMessage = "Could not load album: $e";
      notifyListeners();
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0; 
    }
    await _loadAndPlay();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await _loadAndPlay();
    }
  }

  Future<void> _loadAndPlay() async {
    _isLoadingSong = true;
    notifyListeners();
    
    try {
      final song = _queue[_currentIndex];
      
      // FIX 1: Remove 'ytClients'. Let the library use its Default Client.
      // The Default Client is more reliable for Official Music (The Weeknd, etc.)
      var manifest = await _yt.videos.streamsClient.getManifest(song.id);
      
      // FIX 2: Accept EVERYTHING. 
      // Do not filter by "mp4". Just take the highest quality audio (usually WebM).
      // Android supports WebM/Opus natively.
      var audioStream = manifest.audioOnly.withHighestBitrate();
      
      // FIX 3: Use a Standard Browser Header.
      // This matches the Default Client's behavior and bypasses 403 errors.
      final source = AudioSource.uri(
        audioStream.url,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        },
        tag: MediaItem(
          id: song.id,
          album: "OXCY Music",
          title: song.title,
          artist: song.artist,
          artUri: Uri.parse(song.thumbUrl),
        ),
      );
      
      await _player.setAudioSource(source);
      _player.play();
      
    } catch (e) {
      print("Audio Error: $e");
      // Detailed error for debugging (even if user can't see it)
      _errorMessage = "Playback Error. Song might be restricted.";
      next(); 
    } finally {
      _isLoadingSong = false;
      notifyListeners();
    }
  }
  
  void togglePlayerView() { _isPlayerExpanded = !_isPlayerExpanded; notifyListeners(); }
  void collapsePlayer() { _isPlayerExpanded = false; notifyListeners(); }
  void togglePlayPause() { if (_player.playing) _player.pause(); else _player.play(); }
  void toggleShuffle() { _isShuffling = !_isShuffling; if (_isShuffling) _queue.shuffle(); notifyListeners(); }
  
  void toggleLoop() async {
    if (_loopMode == LoopMode.off) { 
        _loopMode = LoopMode.one; 
        await _player.setLoopMode(LoopMode.one); 
    } else if (_loopMode == LoopMode.one) { 
        _loopMode = LoopMode.all; 
        await _player.setLoopMode(LoopMode.all); 
    } else { 
        _loopMode = LoopMode.off; 
        await _player.setLoopMode(LoopMode.off); 
    }
    notifyListeners();
  }
  
  void clearError() { _errorMessage = null; notifyListeners(); }
}
