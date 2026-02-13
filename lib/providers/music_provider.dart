import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../services/audio_handler.dart';
import '../utils/clients.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;
  final int? localId;
  final Duration? duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    required this.type,
    this.localId,
    this.duration,
  });
}

class MusicProvider with ChangeNotifier {
  AudioHandler? _audioHandler;
  AudioHandler? get audioHandler => _audioHandler;

  // Use a properly configured client for searches, just like the audio handler.
  final _yt = yt.YoutubeExplode(client: createHttpClient());

  List<Song> _localSongs = [];
  List<Song> _shuffledSongs = [];
  List<Song> _searchResults = [];
  bool _isFetchingLocal = false;
  bool _isPlayerExpanded = false;
  bool _isShuffleEnabled = false;

  List<Song> get localSongs => _localSongs;
  List<Song> get searchResults => _searchResults;
  bool get isPlayerExpanded => _isPlayerExpanded;
  bool get isFetchingLocal => _isFetchingLocal;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isMiniPlayerVisible => _audioHandler?.mediaItem.value != null;

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      _audioHandler = await initAudioService();
      
      _audioHandler!.mediaItem
          .throttleTime(const Duration(milliseconds: 100))
          .distinct()
          .listen((_) => notifyListeners());

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
      if (await Permission.audio.request().isGranted ||
          await Permission.storage.request().isGranted) {
        final OnAudioQuery audioQuery = OnAudioQuery();
        List<SongModel> songs = await audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );
        _localSongs = songs
            .where((item) => (item.isMusic == true) && (item.duration ?? 0) > 10000)
            .map((item) => Song(
                  id: item.uri!,
                  title: item.title,
                  artist: item.artist ?? "Unknown",
                  thumbUrl: "",
                  type: 'local',
                  localId: item.id,
                  duration: Duration(milliseconds: item.duration ?? 0),
                ))
            .toList();
        
        if (_isShuffleEnabled) {
          _shuffledSongs = List.from(_localSongs)..shuffle();
          await _updateQueueWithSongs(_shuffledSongs);
        } else {
          await _updateQueueWithSongs(_localSongs);
        }
      }
    } catch (e) {
      print("Local Fetch Error: $e");
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _searchResults = [];
    notifyListeners();
    try {
      var results = await _yt.search.getVideos(query);
      _searchResults = results.map((video) => Song(
            id: video.id.value,
            title: video.title,
            author: video.author,
            thumbUrl: video.thumbnails.highResUrl,
            type: 'youtube',
            duration: video.duration,
          )).toList();
    } catch (e) {
      print("Search Error: $e");
      _searchResults = [];
    } finally {
      notifyListeners();
    }
  }

  Future<void> toggleShuffle() async {
    if (_audioHandler == null) return;
    _isShuffleEnabled = !_isShuffleEnabled;
    
    if (_isShuffleEnabled) {
      _shuffledSongs = List.from(_localSongs)..shuffle();
      await _updateQueueWithSongs(_shuffledSongs);
    } else {
      await _updateQueueWithSongs(_localSongs);
    }
    notifyListeners();
  }

  Future<void> _updateQueueWithSongs(List<Song> songs) async {
    final handler = _audioHandler as MyAudioHandler;
    final mediaItems = songs.map(_songToMediaItem).toList();
    await handler.updateQueue(mediaItems);
  }
  
  // A clean, simple play method.
  Future<void> play(Song song) async {
    if (_audioHandler == null) await init();

    final mediaItem = _songToMediaItem(song);

    // For local songs, they are already in the queue. Just skip to it.
    if (song.type == 'local') {
      final queue = _isShuffleEnabled ? _shuffledSongs : _localSongs;
      final index = queue.indexWhere((s) => s.id == song.id);
      if (index != -1) {
        await _audioHandler!.skipToQueueItem(index);
      }
    } else {
      // For YouTube, add it to the queue and play it directly.
      // The AudioHandler will resolve the stream.
      await _audioHandler!.addQueueItem(mediaItem);
      await _audioHandler!.skipToQueueItem(_audioHandler!.queue.value.length - 1);
    }
    
    // Always call play to ensure playback starts.
    _audioHandler!.play();

    // Expand player UI
    if (!_isPlayerExpanded) {
      _isPlayerExpanded = true;
      notifyListeners();
    }
  }

  MediaItem _songToMediaItem(Song s) {
    return MediaItem(
      id: s.id,
      album: s.type == 'local' ? "Local Music" : "YouTube",
      title: s.title,
      artist: s.artist,
      artUri: s.type == 'youtube' ? Uri.parse(s.thumbUrl) : null,
      genre: s.type,
      duration: s.duration,
      extras: {'artworkId': s.localId},
    );
  }

  void togglePlayPause() {
    if (_audioHandler?.playbackState.value.playing == true) {
      _audioHandler!.pause();
    } else {
      _audioHandler!.play();
    }
  }

  void next() => _audioHandler?.skipToNext();
  void previous() => _audioHandler?.skipToPrevious();
  void seek(Duration pos) => _audioHandler?.seek(pos);

  void togglePlayerView() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    if (_isPlayerExpanded) {
      _isPlayerExpanded = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
