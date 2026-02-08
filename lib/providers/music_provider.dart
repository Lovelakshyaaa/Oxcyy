import 'dart:async';
import 'dart:convert';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart'; // REQUIRED for Local
import 'package:permission_handler/permission_handler.dart'; // REQUIRED for Permissions

// ====================================================================
// DATA MODEL
// ====================================================================

class Song {
  final String id;        // YouTube ID or Local File Path
  final String title;
  final String artist;
  final String thumbUrl;  // URL for YouTube, or Empty for Local (Handled by UI)
  final String type;      // 'video', 'playlist', or 'local'
  final int? localId;     // For fetching local album art

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    this.type = 'video',
    this.localId,
  });
}

// ====================================================================
// MUSIC PROVIDER
// ====================================================================

class MusicProvider with ChangeNotifier {
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  final _player = AudioPlayer();
  final _yt = yt.YoutubeExplode(); 
  final _audioQuery = OnAudioQuery(); // Local File Scanner

  // Lists
  List<Song> _searchResults = [];
  List<Song> _localSongs = [];
  List<Song> _queue = [];
  
  // State
  int _currentIndex = -1;
  bool _isLoadingSong = false;
  bool _isFetchingLocal = false;
  String? _errorMessage;
  
  // Player State
  bool _isMiniPlayerVisible = false;
  bool _isPlayerExpanded = false;
  bool _isShuffling = false;
  LoopMode _loopMode = LoopMode.off;

  // Getters
  AudioPlayer get player => _player;
  List<Song> get searchResults => _searchResults;
  List<Song> get localSongs => _localSongs;
  List<Song> get queue => _queue;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) 
      ? _queue[_currentIndex] 
      : null;
      
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isShuffling => _isShuffling;
  LoopMode get loopMode => _loopMode;
  bool get isLoadingSong => _isLoadingSong;
  bool get isFetchingLocal => _isFetchingLocal;
  String? get errorMessage => _errorMessage;

  MusicProvider() {
    _initAudioSession();
    _setupPlayerListeners();
    fetchLocalSongs(); // Auto-load on start
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _setupPlayerListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });
  }

  // ====================================================================
  // 1. LOCAL AUDIO LOGIC (The New Home Feature)
  // ====================================================================

  Future<void> fetchLocalSongs() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      // 1. Request Permission
      // Android 13+ needs READ_MEDIA_AUDIO, Older needs READ_EXTERNAL_STORAGE
      if (await Permission.audio.request().isGranted || 
          await Permission.storage.request().isGranted) {
        
        // 2. Query Files
        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        // 3. Map to our Song Model
        _localSongs = songs.map((item) {
          return Song(
            id: item.data, // Stores the File Path!
            title: item.title,
            artist: item.artist ?? "Unknown Artist",
            thumbUrl: "", // Local art is handled by ID
            type: 'local',
            localId: item.id, // Needed for artwork query
          );
        }).toList();
      }
    } catch (e) {
      print("Local Fetch Error: $e");
    }

    _isFetchingLocal = false;
    notifyListeners();
  }

  Future<void> playLocal(Song song) async {
    await _player.stop();
    _queue = _localSongs; // Set queue to all local songs
    _currentIndex = _localSongs.indexOf(song);
    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    _errorMessage = null;

    try {
      final source = AudioSource.uri(
        Uri.parse(song.id), // song.id IS the file path
        tag: MediaItem(
          id: song.localId.toString(),
          album: "Local Music",
          title: song.title,
          artist: song.artist,
          artUri: null, // Placeholder
        ),
      );
      
      await _player.setAudioSource(source);
      _player.play();
    } catch (e) {
      _errorMessage = "Could not play file.";
      notifyListeners();
    }
  }

  // ====================================================================
  // 2. STREAMING LOGIC (The Search Feature)
  // ====================================================================

  Future<void> search(String query) async {
    // ... (Keep your existing search logic) ...
    // For brevity, I assume you kept the search logic from previous steps.
    // If not, I can repaste it, but we focus on Local now.
    
    // SIMPLE SEARCH IMPLEMENTATION
    try {
      _searchResults = [];
      notifyListeners();
      String url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&maxResults=20&key=$_apiKey';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> items = data['items'];
        _searchResults = items.map((item) {
          return Song(
            id: item['id']['videoId'],
            title: item['snippet']['title'],
            artist: item['snippet']['channelTitle'],
            thumbUrl: item['snippet']['thumbnails']['high']['url'],
            type: 'video',
          );
        }).toList();
        notifyListeners();
      }
    } catch(e) { print(e); }
  }

  Future<void> playStream(Song song) async {
    // ... (The Cobalt/Lemnos Logic) ...
    // This is called from the Search Screen
    await _player.stop();
    _queue = [song];
    _currentIndex = 0;
    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    
    // Quick Cobalt Implementation for completeness
    try {
       final response = await http.post(
        Uri.parse('https://cobalt.gamemonk.net/api/json'),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        body: jsonEncode({'url': 'https://www.youtube.com/watch?v=${song.id}', 'isAudioOnly': true})
      );
      final data = jsonDecode(response.body);
      if (data['url'] != null) {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(data['url']), tag: MediaItem(id: song.id, title: song.title, artist: song.artist)));
        _player.play();
      }
    } catch (e) { _errorMessage = "Stream Error"; notifyListeners(); }
  }

  // ====================================================================
  // 3. CONTROLS
  // ====================================================================
  
  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      if (_queue[_currentIndex].type == 'local') {
        playLocal(_queue[_currentIndex]);
      } else {
        playStream(_queue[_currentIndex]);
      }
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_currentIndex > 0) {
      _currentIndex--;
      if (_queue[_currentIndex].type == 'local') {
        playLocal(_queue[_currentIndex]);
      } else {
        playStream(_queue[_currentIndex]);
      }
    }
  }

  void togglePlayerView() { _isPlayerExpanded = !_isPlayerExpanded; notifyListeners(); }
  void collapsePlayer() { _isPlayerExpanded = false; notifyListeners(); }
  void togglePlayPause() { if (_player.playing) _player.pause(); else _player.play(); }
  void clearError() { _errorMessage = null; notifyListeners(); }
}
