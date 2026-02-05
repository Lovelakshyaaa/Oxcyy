import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

// Enhanced Model
class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;
  final String type; // 'video' or 'playlist'

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
  
  final _yt = YoutubeExplode();
  final _player = AudioPlayer();
  
  // State
  List<Song> _searchResults = []; 
  List<Song> _queue = [];         
  int _currentIndex = -1;
  
  // Pagination State
  String? _nextPageToken;
  String _currentQuery = "";
  bool _isFetchingMore = false;
  
  // UI State
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

  MusicProvider() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });
  }

  // --- SEARCH & INFINITE SCROLL ---

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
      if (_nextPageToken != null) {
        url += "&pageToken=$_nextPageToken";
      }

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
      print("API Error: $e");
    }
  }

  // --- PLAYBACK LOGIC ---

  Future<void> play(Song song) async {
    _queue = [song];
    _currentIndex = 0;
    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    await _loadAndPlay();
  }

  Future<void> playPlaylist(Song album) async {
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
        if (albumSongs.length >= 50) break;
      }

      if (albumSongs.isNotEmpty) {
        _queue = albumSongs;
        _currentIndex = 0;
        _isMiniPlayerVisible = true;
        _isPlayerExpanded = true;
        await _loadAndPlay();
      }
      
    } catch (e) {
      print("Playlist Error: $e");
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
    notifyListeners();
    try {
      final song = _queue[_currentIndex];
      var manifest = await _yt.videos.streamsClient.getManifest(song.id);
      var audioUrl = manifest.audioOnly.withHighestBitrate().url;
      
      final source = AudioSource.uri(
        audioUrl,
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
      _player.stop();
    }
  }
  
  void togglePlayerView() { _isPlayerExpanded = !_isPlayerExpanded; notifyListeners(); }
  void collapsePlayer() { _isPlayerExpanded = false; notifyListeners(); }
  void togglePlayPause() { if (_player.playing) _player.pause(); else _player.play(); }
  
  Future<void> toggleShuffle() async {
    _isShuffling = !_isShuffling;
    if (_isShuffling) _queue.shuffle();
    notifyListeners();
  }

  Future<void> toggleLoop() async {
    if (_loopMode == LoopMode.off) { _loopMode = LoopMode.one; await _player.setLoopMode(LoopMode.one); }
    else if (_loopMode == LoopMode.one) { _loopMode = LoopMode.all; await _player.setLoopMode(LoopMode.all); }
    else { _loopMode = LoopMode.off; await _player.setLoopMode(LoopMode.off); }
    notifyListeners();
  }
}
