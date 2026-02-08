import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;
  final int? localId;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    required this.type,
    this.localId,
  });
}

class MusicProvider with ChangeNotifier {
  AudioHandler? _audioHandler;
  final _yt = yt.YoutubeExplode();
  
  List<Song> _localSongs = [];
  List<Song> _searchResults = [];
  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isFetchingLocal = false;
  bool _isMiniPlayerVisible = false;
  bool _isPlayerExpanded = false;
  bool _isPlaying = false;
  bool _isInitialized = false;
  
  // Real buffering state (Controls Spinner)
  bool _isBuffering = false; 

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Getters
  List<Song> get localSongs => _localSongs;
  List<Song> get searchResults => _searchResults;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isFetchingLocal => _isFetchingLocal;
  bool get isLoadingSong => _isBuffering; 
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
  Duration get position => _position;
  Duration get duration => _duration;
  
  Stream<PlaybackState>? get playbackState => _audioHandler?.playbackState;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _audioHandler = await initAudioService();
      
      // 1. LISTEN TO STATE
      _audioHandler!.playbackState.listen((state) {
        _isPlaying = state.playing;
        _position = state.position;
        // Sync Spinner with Real Buffering
        _isBuffering = state.processingState == AudioProcessingState.loading || 
                       state.processingState == AudioProcessingState.buffering;
        notifyListeners();
      });
      
      // 2. LISTEN TO DURATION (Fixes 0:00)
      _audioHandler!.mediaItem.listen((item) {
        if (item?.duration != null) {
          _duration = item!.duration!;
          notifyListeners();
        }
      });
      
      AudioService.position.listen((pos) {
        _position = pos;
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();
      await fetchLocalSongs(); 
    } catch (e) {
      print("Init Error: $e");
    }
  }

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

  Future<void> search(String query) async {
    _searchResults = [];
    notifyListeners();
    try {
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

  Future<void> play(Song song) async {
    if (_audioHandler == null) return;

    if (song.type == 'local') {
      _queue = _localSongs;
    } else {
      _queue = [song];
    }
    _currentIndex = _queue.indexOf(song);
    if (_currentIndex == -1) _currentIndex = 0;

    _isMiniPlayerVisible = true;
    _isPlayerExpanded = true;
    _isBuffering = true; // Show spinner immediately
    notifyListeners();

    try {
      String playUrl = "";
      if (song.type == 'local') {
        playUrl = song.id; 
      } else {
        playUrl = await _getStreamUrl(song.id); 
      }

      if (playUrl.isEmpty) throw Exception("No URL found");

      final mediaItem = MediaItem(
        id: playUrl,
        album: song.type == 'local' ? "Local Music" : "YouTube",
        title: song.title,
        artist: song.artist,
        artUri: song.type == 'video' ? Uri.parse(song.thumbUrl) : null,
        extras: {'localId': song.localId},
      );

      await (_audioHandler as MyAudioHandler).playMediaItem(mediaItem);

    } catch (e) {
      print("Play Error: $e");
      _isBuffering = false;
      notifyListeners();
    }
  }

  Future<String> _getStreamUrl(String id) async {
    try {
      var manifest = await _yt.videos.streamsClient.getManifest(id);
      return manifest.audioOnly.withHighestBitrate().url.toString();
    } catch (e) { 
      try {
        var res = await http.get(Uri.parse('https://yt.lemnoslife.com/videos?part=streaming&id=$id'));
        var data = jsonDecode(res.body);
        return data['items'][0]['streamingData']['adaptiveFormats']
            .firstWhere((f) => f['mimeType'].contains('audio/mp4'))['url'];
      } catch (e) { return ""; }
    }
    return "";
  }

  void togglePlayPause() {
    if (_audioHandler == null) return;
    if (_isPlaying) _audioHandler!.pause();
    else _audioHandler!.play();
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

  void seek(Duration pos) => _audioHandler?.seek(pos);
  void togglePlayerView() { _isPlayerExpanded = !_isPlayerExpanded; notifyListeners(); }
  void collapsePlayer() { _isPlayerExpanded = false; notifyListeners(); }
}
