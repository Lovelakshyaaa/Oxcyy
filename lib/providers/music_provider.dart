import 'package:audio_session/audio_session.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

// --- DATA MODEL ---
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

// --- PROVIDER ---
class MusicProvider with ChangeNotifier {
  // ⚠️ WARNING: Keep your API Key secret in production!
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  final _yt = YoutubeExplode();
  
  // FIXED: Standard initialization (removed complex load control for stability)
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
    
    // Listen for song completion to auto-play next
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
    // This fixes the "AndroidAudioAttributes" error internally
    _player.setAndroidAudioAttributes(
      const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
    );
  }

  // --- SEARCH (YouTube Data API) ---
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
        // Safely handle if nextPageToken is missing
        _nextPageToken = data['nextPageToken']; 
        List<dynamic> items = data['items'];
        
        List<Song> newResults = items.map((item) {
           var thumbs = item['snippet']['thumbnails'];
           String img = thumbs['high']['url'];
           // Safety check for maxres
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
      } else {
        print("API Error: ${response.body}");
      }
    } catch (e) {
      print("Network Error: $e");
    }
  }

  // --- PLAYBACK ENGINE ---

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
      var playlist = await _yt.playlists.get(album.id);
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
        if (albumSongs.length >= 50) break; // Limit to 50 for performance
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
    // await _player.stop(); // Optional: smoother transition if removed
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0; // Loop back to start
    }
    await _loadAndPlay();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      // await _player.stop();
      _currentIndex--;
      await _loadAndPlay();
    }
  }

  Future<void> _loadAndPlay() async {
    _isLoadingSong = true;
    notifyListeners();
    
    try {
      final song = _queue[_currentIndex];
      
      // FIXED: Use standard manifest fetching
      // The 'ytClients' parameter does NOT exist in standard version 3.0.5
      var manifest = await _yt.videos.streamsClient.getManifest(song.id);
      
      // Get the best audio-only stream (m4a)
      var audioStream = manifest.audioOnly.withHighestBitrate();
      
      final source = AudioSource.uri(
        audioStream.url,
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
      _errorMessage = "Playback Error. Song might be restricted.";
      // Auto-skip on error (optional)
      // next(); 
    } finally {
      _isLoadingSong = false;
      notifyListeners();
    }
  }
  
  // --- CONTROLS ---
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
