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
  
  // The UI will access the real engine through this getter.
  AudioHandler? get audioHandler => _audioHandler; 

  final _yt = yt.YoutubeExplode();
  
  // --- Business Logic State (Fetching and holding song lists) ---
  List<Song> _localSongs = [];
  List<Song> _searchResults = [];
  bool _isFetchingLocal = false;

  // --- UI-Specific State (Only for controlling UI elements) ---
  bool _isPlayerExpanded = false;
  
  // Getters for the business and UI state.
  List<Song> get localSongs => _localSongs;
  List<Song> get searchResults => _searchResults;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isFetchingLocal => _isFetchingLocal;
  
  // --- GHOST STATE HAS BEEN EXORCISED ---
  // No more _queue, _currentIndex, _isPlaying, _isBuffering, _position, or _duration.
  // The UI will now get this information directly from the `audioHandler` streams.

  // This getter determines visibility based on the REAL source of truth.
  bool get isMiniPlayerVisible => _audioHandler?.mediaItem.value != null;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      _audioHandler = await initAudioService();
      
      // We listen to the mediaItem stream only to know when to update the UI's
      // visibility, not to manage state.
      _audioHandler!.mediaItem.listen((_) {
        notifyListeners();
      });

      _isInitialized = true;
      notifyListeners();
      await fetchLocalSongs(); 
    } catch (e) {
      print("Provider Init Error: $e");
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
          // The ID for local songs MUST be the content URI for the handler to work.
          return Song(
            id: item.uri!, 
            title: item.title,
            artist: item.artist ?? "Unknown",
            thumbUrl: "", // Not applicable for local
            type: 'local',
            localId: item.id,
          );
        }).toList();
      }
    } catch (e) { print("Local Fetch Error: $e"); }
    _isFetchingLocal = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _searchResults = [];
    notifyListeners();
    try {
      var results = await _yt.search.getVideos(query);
      _searchResults = results.map((video) => Song(
        id: video.id.value, // For YouTube, the ID is the video ID.
        title: video.title,
        artist: video.author,
        thumbUrl: video.thumbnails.highResUrl,
        type: 'youtube', // Use 'youtube' as genre
      )).toList();
      notifyListeners();
    } catch (e) { print("Search Error: $e"); }
  }

  // *** THE CRITICAL FIX: This method now correctly controls the AudioHandler ***
  Future<void> play(Song song) async {
    if (_audioHandler == null) await init();
    // Ensure the handler is the one with queue capabilities
    final handler = _audioHandler as MyAudioHandler;

    List<Song> songQueue;
    // When a local song is played, the queue is the entire list of local songs.
    if (song.type == 'local') {
      songQueue = _localSongs;
    } else {
      // When a searched song is played, the queue is just that single song.
      songQueue = [song]; 
    }

    final initialIndex = songQueue.indexWhere((s) => s.id == song.id);
    if (initialIndex < 0) return;

    // Convert our business `Song` objects into `MediaItem` objects for the engine.
    final mediaItems = songQueue.map((s) {
      return MediaItem(
        id: s.id, // For local files, this is the content URI. For YouTube, it's the video ID.
        album: s.type == 'local' ? "Local Music" : "YouTube",
        title: s.title,
        artist: s.artist,
        artUri: s.type == 'youtube' ? Uri.parse(s.thumbUrl) : null,
        genre: s.type, // The handler uses this to know how to process the ID.
        extras: {'artworkId': s.localId}, // Pass the artwork ID for the UI fix.
      );
    }).toList();

    // Delegate the entire playback operation to the AudioHandler.
    await handler.updateQueue(mediaItems);
    await handler.skipToQueueItem(initialIndex);
    
    // Now, we can manage the UI state. This will make the player appear.
    _isPlayerExpanded = true;
    notifyListeners();
  }

  // This is no longer needed here as the handler resolves the URL.
  // Future<String> _getStreamUrl(String id) async { ... }

  // --- All controls are now simple delegations to the real engine ---
  void togglePlayPause() {
    if (_audioHandler?.playbackState.value.playing == true) {
      _audioHandler!.pause();
    } else {
      _audioHandler!.play();
    }
  }
  
  void next() => (_audioHandler as QueueHandler?)?.skipToNext();
  
  void previous() => (_audioHandler as QueueHandler?)?.skipToPrevious();

  void seek(Duration pos) => _audioHandler?.seek(pos);
  
  // These UI state methods remain as they only affect the UI.
  void togglePlayerView() { 
    _isPlayerExpanded = !_isPlayerExpanded; 
    notifyListeners(); 
  }

  void collapsePlayer() { 
    _isPlayerExpanded = false; 
    notifyListeners(); 
  }
}
