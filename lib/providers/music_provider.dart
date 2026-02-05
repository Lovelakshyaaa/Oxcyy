import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart'; // REQUIRED

class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;

  Song({required this.id, required this.title, required this.artist, required this.thumbUrl});
}

class MusicProvider with ChangeNotifier {
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  final _yt = YoutubeExplode();
  final _player = AudioPlayer();
  
  List<Song> _queue = [];
  int _currentIndex = -1;
  bool _isMiniPlayerVisible = false;
  bool _isPlayerExpanded = false;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;

  // Getters
  AudioPlayer get player => _player;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isShuffling => _isShuffling;
  LoopMode get loopMode => _loopMode;
  List<Song> get queue => _queue;

  MusicProvider() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });
  }

  // --- CONTROLS ---

  void togglePlayerView() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    _isPlayerExpanded = false;
    notifyListeners();
  }

  Future<void> play(Song song) async {
    if (_queue.isEmpty || !_queue.contains(song)) {
      _queue = [song];
      _currentIndex = 0;
    } else {
      _currentIndex = _queue.indexOf(song);
    }

    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    await _loadAndPlay();
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

  Future<void> toggleShuffle() async {
    _isShuffling = !_isShuffling;
    if (_isShuffling) {
      _queue.shuffle();
    }
    notifyListeners();
  }

  Future<void> toggleLoop() async {
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

  Future<void> _loadAndPlay() async {
    notifyListeners();
    try {
      final song = _queue[_currentIndex];
      
      // Get Audio URL
      var manifest = await _yt.videos.streamsClient.getManifest(song.id);
      var audioUrl = manifest.audioOnly.withHighestBitrate().url;
      
      // BACKGROUND SOURCE SETUP
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
      print("Error playing audio: $e");
      // Stop the player so it doesn't loop infinitely
      _player.stop(); 
    }
  }

  void togglePlayPause() {
    if (_player.playing) _player.pause();
    else _player.play();
  }

  // --- SEARCH FIX ---
  
  Future<List<Song>> search(String query) async {
    notifyListeners();
    try {
      // ADDED: videoCategoryId=10 (Music) to filter trash
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&videoCategoryId=10&maxResults=30&key=$_apiKey'
      );
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> items = data['items'];
        
        List<Song> results = items.map((item) {
           var thumbs = item['snippet']['thumbnails'];
           String img = thumbs['high']['url'];
           if (thumbs.containsKey('maxres')) img = thumbs['maxres']['url'];

          return Song(
            id: item['id']['videoId'],
            title: item['snippet']['title'],
            artist: item['snippet']['channelTitle'],
            thumbUrl: img,
          );
        }).toList();
        
        _queue = results; // Update queue context
        notifyListeners();
        return results;
      }
    } catch (e) {
      print("API Error: $e");
    }
    notifyListeners();
    return [];
  }
}
