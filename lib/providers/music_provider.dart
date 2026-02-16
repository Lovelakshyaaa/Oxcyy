import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';
import 'package:yt_flutter_musicapi/models/searchModel.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/services/audio_handler.dart';

// Represents a single song, abstracting over local and YouTube sources.
class Song {
  final String id; // videoId for YouTube, file URI for local
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;
  final String? audioUrl; // Playable URL for YouTube songs
  final int? localId;
  final int? albumId;
  final Duration? duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    required this.type,
    this.audioUrl,
    this.localId,
    this.albumId,
    this.duration,
  });
}

// Manages the application's music state, including search, playback, and local files.
class MusicProvider with ChangeNotifier {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final YtFlutterMusicapi _yt = YtFlutterMusicapi();

  AudioHandler? _audioHandler;
  AudioHandler? get audioHandler => _audioHandler;

  // Artwork Caching
  final Map<String, Uint8List> _artworkCache = {};

  List<Song> _searchResults = [];
  List<Song> get searchResults => _searchResults;

  List<AlbumModel> _localAlbums = [];
  List<AlbumModel> get localAlbums => _localAlbums;

  List<Song> _localSongs = [];
  List<Song> get localSongs => _localSongs;

  List<Song> _shuffledSongs = [];

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _isFetchingLocal = true;
  bool get isFetchingLocal => _isFetchingLocal;

  bool _isPlayerExpanded = false;
  bool get isPlayerExpanded => _isPlayerExpanded;

  bool _isShuffleEnabled = false;
  bool get isShuffleEnabled => _isShuffleEnabled;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  MusicProvider() {
    _init();
  }

  Future<void> _init() async {
    await _yt.initialize();
    _audioHandler = await initAudioService();
    _audioHandler?.playbackState.listen((playbackState) {
      if (_repeatMode != playbackState.repeatMode) {
        _repeatMode = playbackState.repeatMode;
        notifyListeners();
      }
    });
    fetchLocalMusic();
  }

  Future<void> fetchLocalMusic() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      if (await Permission.audio.request().isGranted || await Permission.storage.request().isGranted) {
        List<AlbumModel> albums = await _audioQuery.queryAlbums(
          sortType: AlbumSortType.ALBUM,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        _localAlbums = albums;
        _localSongs = songs
            .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 10000)
            .map((s) => Song(
                  id: s.uri!,
                  title: s.title,
                  artist: s.artist ?? "Unknown",
                  thumbUrl: "",
                  type: 'local',
                  localId: s.id,
                  albumId: s.albumId,
                  duration: Duration(milliseconds: s.duration ?? 0),
                ))
            .toList();

        _shuffledSongs = List.from(_localSongs)..shuffle();

        if (_audioHandler != null) {
          await _updateQueueWithSongs(_isShuffleEnabled ? _shuffledSongs : _localSongs);
        }
      }
    } catch (e) {
      print("Error fetching local music: $e");
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  Future<List<Song>> getLocalSongsByAlbum(int albumId) async {
    List<SongModel> albumSongs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      albumId,
      orderType: OrderType.ASC_OR_SMALLER,
    );

    albumSongs.sort((a, b) {
      int trackA = int.tryParse(a.track.toString()) ?? 0;
      int trackB = int.tryParse(b.track.toString()) ?? 0;
      return trackA.compareTo(trackB);
    });

    return albumSongs
        .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 10000)
        .map((s) => Song(
              id: s.uri!,
              title: s.title,
              artist: s.artist ?? "Unknown",
              thumbUrl: "",
              type: 'local',
              localId: s.id,
              albumId: s.albumId,
              duration: Duration(milliseconds: s.duration ?? 0),
            ))
        .toList();
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) async {
    final String cacheKey = '${type.toString()}_$id';
    if (_artworkCache.containsKey(cacheKey)) return _artworkCache[cacheKey];

    final Uint8List? artwork = await _audioQuery.queryArtwork(id, type, format: ArtworkFormat.PNG, size: 2048);
    if (artwork != null) _artworkCache[cacheKey] = artwork;
    return artwork;
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _isSearching = true;
    _searchResults.clear();
    notifyListeners();

    try {
      await for (final SearchResult result in _yt.streamSearchResults(
        query: query,
        includeAudioUrl: true,
        audioQuality: AudioQuality.high,
      )) {
        Duration? songDuration;
        if (result.duration is String) {
            final parts = result.duration!.split(':');
            if (parts.length == 2) {
                songDuration = Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
            }
        }

        final song = Song(
            id: result.videoId,
            title: result.title,
            artist: result.artists, // artists is a String
            thumbUrl: result.albumArt ?? '',
            type: 'youtube',
            duration: songDuration,
            audioUrl: result.audioUrl,
        );
        _searchResults.add(song);
        notifyListeners();
      }
    } catch (e) {
      print("Error searching YouTube: $e");
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> play(Song song, {List<Song>? newQueue}) async {
    if (_audioHandler == null) return;

    try {
      final mediaItem = _songToMediaItem(song);
      
      if (song.type == 'youtube') {
         // For youtube, we just play the single item
         await (_audioHandler! as MyAudioHandler).playMediaItem(mediaItem);
      } else {
          // For local files, we manage the queue
          List<Song> queueToPlay = newQueue ?? (_isShuffleEnabled ? _shuffledSongs : _localSongs);
          if (newQueue != null) {
            await _updateQueueWithSongs(queueToPlay);
          }
          
          final index = queueToPlay.indexWhere((s) => s.id == song.id);
          if (index != -1) {
            await _audioHandler!.skipToQueueItem(index);
            await _audioHandler!.play();
          }
      }

      if (!_isPlayerExpanded) {
        _isPlayerExpanded = true;
        notifyListeners();
      }
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  Future<void> _updateQueueWithSongs(List<Song> songs) async {
    final mediaItems = songs.map(_songToMediaItem).toList();
    await _audioHandler!.updateQueue(mediaItems);
  }

  MediaItem _songToMediaItem(Song s) {
    // The ID for MediaItem MUST be the playable URI.
    // For local songs, it's the file path (s.id).
    // For YouTube songs, it's the fetched audio URL (s.audioUrl).
    String playableId = (s.type == 'youtube') ? (s.audioUrl ?? '') : s.id;

    return MediaItem(
      id: playableId,
      album: s.type == 'local' ? "Local Music" : "YouTube",
      title: s.title,
      artist: s.artist,
      artUri: s.type == 'youtube' ? Uri.parse(s.thumbUrl) : null,
      genre: s.type,
      duration: s.duration,
      extras: {'artworkId': s.localId, 'albumId': s.albumId, 'videoId': s.id},
    );
  }

  void togglePlayPause() {
    _audioHandler?.playbackState.value.playing == true ? _audioHandler!.pause() : _audioHandler!.play();
  }

  void next() => _audioHandler?.skipToNext();
  void previous() => _audioHandler?.skipToPrevious();
  void seek(Duration pos) => _audioHandler?.seek(pos);

  void cycleRepeatMode() {
    if (_audioHandler == null) return;
    final nextMode = {
      AudioServiceRepeatMode.none: AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all: AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one: AudioServiceRepeatMode.none,
    }[_repeatMode];

    if (nextMode != null) {
      _repeatMode = nextMode;
      notifyListeners(); 
      _audioHandler!.setRepeatMode(nextMode);
    }
  }

  void toggleShuffle() {
    if (_audioHandler == null) return;
    _isShuffleEnabled = !_isShuffleEnabled;
    final newMode = _isShuffleEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
    _audioHandler!.setShuffleMode(newMode);

    if (_isShuffleEnabled) {
      _shuffledSongs = List.from(_localSongs)..shuffle();
      _updateQueueWithSongs(_shuffledSongs);
    } else {
      _updateQueueWithSongs(_localSongs);
    }

    notifyListeners();
  }

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
    // No close method on the api object
    super.dispose();
  }
}
