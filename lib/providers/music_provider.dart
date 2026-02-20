
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:oxcy/models/search_models.dart';

// Manages the audio player, playback state, queue, and background notifications.
class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // --- State Properties ---
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isPlayerVisible = false; // Controls the visibility of the player UI.
  String? _errorMessage;
  String? _loadingSongId; // ID of the song currently being prepared.

  bool _isFetchingLocal = false;
  List<AlbumModel> _localAlbums = [];

  // --- Getters for UI ---
  Song? get currentSong => _currentSong;
  bool get isPlaying => _audioPlayer.playing;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  bool get isPlayerVisible => _isPlayerVisible;
  String? get errorMessage => _errorMessage;
  String? get loadingSongId => _loadingSongId;
  LoopMode get repeatMode => _audioPlayer.loopMode;
  bool get isShuffleEnabled => _audioPlayer.shuffleModeEnabled;
  bool get isFetchingLocal => _isFetchingLocal;
  List<AlbumModel> get localAlbums => _localAlbums;

  // --- Streams for real-time UI updates ---
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  MusicProvider() {
    _listenToPlayerState();
  }

  /// Sets up listeners for player state changes to automatically update the UI.
  void _listenToPlayerState() {
    // Listen for the currently playing item in the playlist to change.
    _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && index != _currentIndex && index < _queue.length) {
        _currentIndex = index;
        _currentSong = _queue[_currentIndex];
        notifyListeners();
      }
    });

    // Listen for the player to complete a track and automatically move to the next one.
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _audioPlayer.seekToNext();
      }
    });
  }

  /// The core function to start playback of a song.
  Future<void> play(dynamic song, {List<dynamic>? newQueue}) async {
    _loadingSongId = song.id.toString();
    _isPlayerVisible = true; // Show the player UI.
    notifyListeners();

    try {
      List<dynamic> queue = newQueue ?? [song];
      int initialIndex = queue.indexWhere((s) => s.id == song.id);
      if (initialIndex == -1) initialIndex = 0;

      if (song is SongModel) {
        final audioSources = queue.map((track) {
          return AudioSource.uri(
            Uri.parse(track.uri!),
            tag: {
              'id': track.id.toString(),
              'title': track.title,
              'artist': track.artist,
            },
          );
        }).toList();
        final playlistSource = ConcatenatingAudioSource(children: audioSources);
        await _audioPlayer.setAudioSource(playlistSource, initialIndex: initialIndex, initialPosition: Duration.zero);
      } else {
        _queue = queue.cast<Song>();
        final audioSources = _queue.map((track) {
          final streamUrl = track.highQualityStreamUrl;
          if (streamUrl == null) return null;

          return AudioSource.uri(
            Uri.parse(streamUrl),
            tag: {
              'id': track.id,
              'title': track.name,
              'artist': track.artistNames,
              'artUri': track.highQualityImageUrl,
            },
          );
        }).whereType<AudioSource>().toList();

        if (audioSources.isEmpty) {
          _setError("Could not prepare any song for playback. The stream URL might be missing.");
          return;
        }

        _currentSong = _queue[initialIndex];
        _currentIndex = initialIndex;

        final playlistSource = ConcatenatingAudioSource(children: audioSources);
        await _audioPlayer.setAudioSource(playlistSource, initialIndex: initialIndex, initialPosition: Duration.zero);
      }
      _audioPlayer.play();

    } catch (e) {
      print("Error in play method: $e");
      _setError("An error occurred. The audio stream may not be available.");
    } finally {
      _loadingSongId = null;
      notifyListeners();
    }
  }

  // --- Playback Controls ---
  void resume() => _audioPlayer.play();
  void pause() => _audioPlayer.pause();
  void seek(Duration position) => _audioPlayer.seek(position);
  Future<void> playNext() => _audioPlayer.seekToNext();
  Future<void> playPrevious() => _audioPlayer.seekToPrevious();

  // --- UI and Mode Controls ---
  void showPlayer() {
    _isPlayerVisible = true;
    notifyListeners();
  }

  void hidePlayer() {
    _isPlayerVisible = false;
    notifyListeners();
  }
  
  void cycleRepeatMode() {
    final nextMode = {
      LoopMode.off: LoopMode.all,
      LoopMode.all: LoopMode.one,
      LoopMode.one: LoopMode.off,
    }[_audioPlayer.loopMode] ?? LoopMode.off;
    _audioPlayer.setLoopMode(nextMode);
    notifyListeners();
  }

  void toggleShuffle() {
    _audioPlayer.setShuffleModeEnabled(!_audioPlayer.shuffleModeEnabled).then((_) => notifyListeners());
  }

  // --- Error Handling ---
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
    return _audioQuery.querySongs( sortType: SongSortType.TITLE);
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) {
    return _audioQuery.queryArtwork(id, type);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
