import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // For Search/Proxy
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';

// ====================================================================
// DATA MODEL
// ====================================================================
class Song {
  final String id;        // File Path or YouTube ID
  final String title;
  final String artist;
  final String thumbUrl;  // Empty for local
  final String type;      // 'local' or 'video'
  final int? localId;     // For Local Artwork

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    required this.type,
    this.localId,
  });
}

// ====================================================================
// MUSIC PROVIDER (HYBRID)
// ====================================================================
class MusicProvider with ChangeNotifier {
  late AudioHandler _audioHandler;
  final _yt = yt.YoutubeExplode();
  
  List<Song> _localSongs = [];
  List<Song> _searchResults = [];
  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isFetchingLocal = false;
  bool _isLoadingSong = false;
  bool _isMiniPlayerVisible = false;
  bool _isPlayerExpanded = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Getters
  List<Song> get localSongs => _localSongs;
  List<Song> get searchResults => _searchResults;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isFetchingLocal => _isFetchingLocal;
  bool get isLoadingSong => _isLoadingSong;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  
  // Expose stream for UI
  Stream<PlaybackState> get playbackState => _audioHandler.playbackState;

  Future<void> init() async {
    _audioHandler = await initAudioService();
    _audioHandler.playbackState.listen((state) {
      _isPlaying = state.playing;
      _position = state.position;
      notifyListeners();
    });
    AudioService.position.listen((pos) {
      _position = pos;
      notifyListeners();
    });
    fetchLocalSongs();
  }

  // 1. LOCAL FETCH
  Future<void> fetchLocalSongs() async {
    _isFetchingLocal = true;
    notifyListeners();
    try {
      if (await Permission.audio.request().isGranted || await Permission.storage.request().isGranted) {
        final OnAudioQuery audioQuery = OnAudioQuery();
        List<SongModel> songs = await audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        _localSongs = songs.where((item) => (item.isMusic == true) && (item.duration ?? 0) > 10000).map((item) {
          return Song(
            id: item.data, 
            title: item.title,
            artist: item.artist ?? "Unknown",
            thumbUrl: "",
            type: 'local',
            localId: item.id,
          );
        }).toList();
      }
    } catch (e) { print("Local Error: $e"); }
    _isFetchingLocal = false;
    notifyListeners();
  }

  // 2. YOUTUBE SEARCH
  Future<void> search(String query) async {
    _searchResults = [];
    notifyListeners();
    try {
      // Use YouTube Explode for search (Hemant Fork)
      var results = await _yt.search.getVideos(query);
      _searchResults = results.map((video) => Song(
        id: video.id.value,
        title: video.title,
        artist: video.author,
        thumbUrl: video.thumbnails.highResUrl,
        type: 'video',
      )).toList();
      notifyListeners();
    } catch (e) { print("Search Error: $e"); }
  }

  // 3. UNIVERSAL PLAY
  Future<void> play(Song song) async {
    if (song.type == 'local') {
      _queue = _localSongs;
    } else {
      _queue = [song]; // Simple queue for search
    }
    _currentIndex = _queue.indexOf(song);
    if (_currentIndex == -1) _currentIndex = 0;

    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    _isLoadingSong = true;
    notifyListeners();

    try {
      String playUrl = "";
      
      if (song.type == 'local') {
        playUrl = song.id; // It's a file path
      } else {
        // YOUTUBE EXTRACTION (Nuclear Option)
        playUrl = await _getStreamUrl(song.id); 
      }

      if (playUrl.isEmpty) throw Exception("No URL found");

      final mediaItem = MediaItem(
        id: playUrl,
        album: song.type == 'local' ? "Local Music" : "YouTube",
        title: song.title,
        artist: song.artist,
        artUri: song.type == 'video' ? Uri.parse(song.thumbUrl) : null,
        extras: {'localId': song.localId}, // Pass ID for local art
      );

      await (_audioHandler as MyAudioHandler).playMediaItem(mediaItem);
      _isLoadingSong = false;
      notifyListeners();

    } catch (e) {
      print("Play Error: $e");
      _isLoadingSong = false;
      notifyListeners();
    }
  }

  Future<String> _getStreamUrl(String id) async {
    // 1. Try Hemant's Library
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(id);
      return manifest.audioOnly.withHighestBitrate().url.toString();
    } catch (e) { print("Lib failed, trying proxy..."); }
    
    // 2. Try LemnosLife (Proxy)
    try {
      var res = await http.get(Uri.parse('https://yt.lemnoslife.com/videos?part=streaming&id=$id'));
      var data = jsonDecode(res.body);
      return data['items'][0]['streamingData']['adaptiveFormats']
          .firstWhere((f) => f['mimeType'].contains('audio/mp4'))['url'];
    } catch (e) { print("Proxy failed"); }
    
    return "";
  }

  // CONTROLS
  void togglePlayPause() {
    if (_isPlaying) _audioHandler.pause();
    else _audioHandler.play();
  }
  
  void next() {
    if (_queue.isEmpty) return;
    if (_currentIndex < _queue.length - 1) play(_queue[_currentIndex + 1]);
    else play(_queue[0]);
  }
  
  void previous() {
    if (_queue.isEmpty) return;
    if (_currentIndex > 0) play(_queue[_currentIndex - 1]);
  }

  void seek(Duration pos) => _audioHandler.seek(pos);
  void togglePlayerView() { _isPlayerExpanded = !_isPlayerExpanded; notifyListeners(); }
  void collapsePlayer() { _isPlayerExpanded = false; notifyListeners(); }
}
