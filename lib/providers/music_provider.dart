import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
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

  final _yt = yt.YoutubeExplode();

  List<Song> _localSongs = [];
  List<Song> _searchResults = [];
  bool _isFetchingLocal = false;
  bool _isPlayerExpanded = false;
  bool _isShuffleEnabled = false;
  List<Song> _originalQueue = [];

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
      _audioHandler!.mediaItem.listen((_) => notifyListeners());
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
      }
    } catch (e) {
      print("Local Fetch Error: $e");
    }
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
            id: video.id.value,
            title: video.title,
            artist: video.author,
            thumbUrl: video.thumbnails.highResUrl,
            type: 'youtube',
            duration: video.duration,
          )).toList();
      notifyListeners();
    } catch (e) {
      print("Search Error: $e");
    }
  }

  Future<void> toggleShuffle() async {
    if (_audioHandler == null) return;
    _isShuffleEnabled = !_isShuffleEnabled;
    if (_isShuffleEnabled) {
      _originalQueue = List.from(_localSongs);
      final shuffled = List<Song>.from(_localSongs)..shuffle();
      await _updateQueueWithSongs(shuffled);
    } else {
      await _updateQueueWithSongs(_originalQueue);
    }
    notifyListeners();
  }

  Future<void> _updateQueueWithSongs(List<Song> songs) async {
    final handler = _audioHandler as MyAudioHandler;
    final mediaItems = songs.map(_songToMediaItem).toList();
    await handler.updateQueue(mediaItems);
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

  Future<void> play(Song song) async {
    if (_audioHandler == null) await init();
    final handler = _audioHandler as MyAudioHandler;

    List<Song> songQueue;
    if (song.type == 'local') {
      songQueue = _isShuffleEnabled ? _originalQueue : _localSongs;
    } else {
      songQueue = [song];
    }

    final initialIndex = songQueue.indexWhere((s) => s.id == song.id);
    if (initialIndex < 0) return;

    final mediaItems = songQueue.map(_songToMediaItem).toList();

    await handler.updateQueue(mediaItems);
    await handler.skipToQueueItem(initialIndex);

    _isPlayerExpanded = true;
    notifyListeners();
  }

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

  void togglePlayerView() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    _isPlayerExpanded = false;
    notifyListeners();
  }
}
