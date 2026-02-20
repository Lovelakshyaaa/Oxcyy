
import 'dart:async';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:oxcy/models/search_models.dart';

class MusicProvider with ChangeNotifier {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioHandler _audioHandler;

  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isPlayerVisible = false;
  String? _errorMessage;
  String? _loadingSongId;

  bool _isFetchingLocal = false;
  List<AlbumModel> _localAlbums = [];

  Song? get currentSong => _currentSong;
  bool get isPlayerVisible => _isPlayerVisible;
  String? get errorMessage => _errorMessage;
  String? get loadingSongId => _loadingSongId;
  bool get isFetchingLocal => _isFetchingLocal;
  List<AlbumModel> get localAlbums => _localAlbums;

  MusicProvider(this._audioHandler) {
    _listenToPlaybackState();
  }

  void _listenToPlaybackState() {
    _audioHandler.playbackState.listen((playbackState) {
      final isPlaying = playbackState.playing;
      final processingState = playbackState.processingState;
      if (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering) {
        _loadingSongId = _audioHandler.mediaItem.value?.id;
      } else {
        _loadingSongId = null;
      }
      notifyListeners();
    });

    _audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        _currentSong = Song.fromJson(mediaItem.extras!['song']);
        _isPlayerVisible = true;
      }
      notifyListeners();
    });
  }

  Future<void> setPlaylist(List<dynamic> songs, {int initialIndex = 0}) async {
    final mediaItems = songs.map((song) {
      return MediaItem(
        id: song.id.toString(),
        title: song.name,
        artist: song.artistNames,
        artUri: Uri.parse(song.highQualityImageUrl),
        extras: {
          'url': song.highQualityStreamUrl,
          'song': song.toJson(),
        },
      );
    }).toList();

    await _audioHandler.updateQueue(mediaItems);
    await _audioHandler.skipToQueueItem(initialIndex);
    await _audioHandler.play();
  }

  Future<void> play(dynamic song) async {
    if (song is Song) {
      final mediaItem = MediaItem(
        id: song.id.toString(),
        title: song.name,
        artist: song.artistNames,
        artUri: Uri.parse(song.highQualityImageUrl),
        extras: {
          'url': song.highQualityStreamUrl,
          'song': song.toJson(),
        },
      );
      await _audioHandler.updateQueue([mediaItem]);
      await _audioHandler.play();
    } else if (song is SongModel) {
      final mediaItem = MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist,
        extras: {
          'url': song.uri,
          'song': song.getMap,
        },
      );
      await _audioHandler.updateQueue([mediaItem]);
      await _audioHandler.play();
    }
  }

  void resume() => _audioHandler.play();
  void pause() => _audioHandler.pause();
  void seek(Duration position) => _audioHandler.seek(position);
  Future<void> playNext() => _audioHandler.skipToNext();
  Future<void> playPrevious() => _audioHandler.skipToPrevious();

  void showPlayer() {
    _isPlayerVisible = true;
    notifyListeners();
  }

  void hidePlayer() {
    _isPlayerVisible = false;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _loadingSongId = null;
    notifyListeners();
  }

  Future<void> fetchLocalMusic() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      _localAlbums = await _audioQuery.queryAlbums();
    } catch (e) {
      _setError("Failed to fetch local music.");
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  Future<List<SongModel>> getLocalSongsByAlbum(int albumId) {
    return _audioQuery.querySongs(sortType: SongSortType.TITLE);
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) {
    return _audioQuery.queryArtwork(id, type);
  }
}
