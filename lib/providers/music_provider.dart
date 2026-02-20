
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:oxcy/models/search_models.dart';

// Manages the audio player, playback state, queue, and background notifications.
class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- State Properties ---
  Song? _currentSong;
  List<Song> _queue = [];
  int _currentIndex = -1;

  bool _isPlayerVisible = false; // Controls the visibility of the player UI.
  String? _errorMessage;
  String? _loadingSongId; // ID of the song currently being prepared.

  // --- Getters for UI ---
  Song? get currentSong => _currentSong;
  bool get isPlaying => _audioPlayer.playing;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  bool get isPlayerVisible => _isPlayerVisible;
  String? get errorMessage => _errorMessage;
  String? get loadingSongId => _loadingSongId;
  LoopMode get repeatMode => _audioPlayer.loopMode;
  bool get isShuffleEnabled => _audioPlayer.shuffleModeEnabled;

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
  Future<void> play(Song song, {List<Song>? newQueue}) async {
    _loadingSongId = song.id;
    _isPlayerVisible = true; // Show the player UI.
    notifyListeners();

    try {
      // Use the provided queue or create a new one with just the selected song.
      _queue = newQueue ?? [song];
      int initialIndex = _queue.indexWhere((s) => s.id == song.id);
      if (initialIndex == -1) initialIndex = 0;

      // Create a list of AudioSource objects for the just_audio player.
      final audioSources = _queue.map((track) {
        // The highQualityStreamUrl getter from our model is now used here.
        final streamUrl = track.highQualityStreamUrl;
        if (streamUrl == null) return null;

        return AudioSource.uri(
          Uri.parse(streamUrl),
          // The MediaItem tag is crucial for background audio notifications.
          tag: MediaItem(
            id: track.id,
            title: track.name,
            artist: track.artistNames, // Use the new artistNames getter.
            artUri: Uri.parse(track.highQualityImageUrl), // Use the high-quality image URL.
          ),
        );
      }).whereType<AudioSource>().toList(); // Filter out any nulls.

      if (audioSources.isEmpty) {
        _setError("Could not prepare any song for playback. The stream URL might be missing.");
        return;
      }

      _currentSong = _queue[initialIndex];
      _currentIndex = initialIndex;

      // Set up the player with the playlist.
      final playlistSource = ConcatenatingAudioSource(children: audioSources);
      await _audioPlayer.setAudioSource(playlistSource, initialIndex: initialIndex, initialPosition: Duration.zero);
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
