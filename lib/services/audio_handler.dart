import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as just;
import 'package:media_kit/media_kit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:oxcy/services/decipher_service.dart';
import 'package:rxdart/rxdart.dart';

// The new, robust AudioHandler that manages two players.
Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.oxcy.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // Two players: one for local files, one for YouTube streams.
  final _justPlayer = just.AudioPlayer();
  final _mediaKitPlayer = Player();

  final _playlist = just.ConcatenatingAudioSource(useLazyPreparation: true, children: []);

  // YouTube and Decipher services
  static final _yt = YoutubeExplode();
  static final _decipherService = DecipherService();

  // Stream controllers to merge states from both players
  final _playbackState = BehaviorSubject<PlaybackState>();

  // To keep track of which player is currently in use
  var _activePlayer = 'none'; // can be 'just', 'media_kit', or 'none'

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await _decipherService.init();

    // Listen to state changes from BOTH players and pipe them to the UI
    _listenToJustPlayerStates();
    _listenToMediaKitPlayerStates();

    // Set the initial audio source for local files
    try {
      await _justPlayer.setAudioSource(_playlist, preload: false);
    } catch (e) {
      print("Error setting initial audio source: $e");
    }
  }

  // ---- Player State Listeners ----

  void _listenToJustPlayerStates() {
    _justPlayer.playbackEventStream.listen((event) {
      if (_activePlayer == 'just') {
        final state = _transformJustAudioEvent(event);
        _playbackState.add(state);
      }
    });

    _justPlayer.sequenceStateStream.listen((sequenceState) {
       if (_activePlayer == 'just' && sequenceState != null) {
        final currentItem = sequenceState.currentSource?.tag as MediaItem?;
        if (currentItem != null) mediaItem.add(currentItem);

        final currentQueue = sequenceState.sequence.map((s) => s.tag as MediaItem).toList();
        if (queue.value != currentQueue) {
          queue.add(currentQueue);
        }
      }
    });
  }

  void _listenToMediaKitPlayerStates() {
    // Combine streams from media_kit to build a PlaybackState
    Rx.combineLatest4(
      _mediaKitPlayer.stream.playing,
      _mediaKitPlayer.stream.position,
      _mediaKitPlayer.stream.buffering,
      _mediaKitPlayer.stream.duration,
      (playing, position, buffering, duration) {
        if (_activePlayer == 'media_kit') {
          final state = _transformMediaKitEvent(playing, position, buffering, duration);
          _playbackState.add(state);
        }
      },
    ).listen((_) {});

    _mediaKitPlayer.stream.completed.listen((completed) {
        if (completed && _activePlayer == 'media_kit') {
            // Handle song completion if necessary (e.g., play next)
            // For now, we just update the state.
            _playbackState.add(_playbackState.value.copyWith(processingState: AudioProcessingState.completed));
        }
    });
  }


  // ---- Core Logic: Switching between players ----

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    if (mediaItem.genre == 'youtube') {
      _activePlayer = 'media_kit';
      await _justPlayer.stop(); // Stop the other player
      this.mediaItem.add(mediaItem); // Manually update the mediaItem
      queue.add([mediaItem]); // Manually update the queue

      try {
        final url = await _getYouTubeStreamUrl(mediaItem.id);
        await _mediaKitPlayer.open(Media(url), play: true);
      } catch (e) {
        print("Error playing YouTube stream: $e");
      }

    } else {
      _activePlayer = 'just';
      await _mediaKitPlayer.stop(); // Stop the other player
      
      // Find the item in the just_audio playlist and play it
      final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
      if (index != -1) {
        await _justPlayer.seek(Duration.zero, index: index);
        await _justPlayer.play();
      }
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    // This method is now for local files only, handled by just_audio
    final audioSources = newQueue.map((item) => just.AudioSource.uri(Uri.parse(item.id), tag: item)).toList();
    await _playlist.clear();
    await _playlist.addAll(audioSources);
    queue.add(newQueue);
  }


  // ---- Playback Controls (Delegation) ----

  @override
  Future<void> play() async {
    if (_activePlayer == 'media_kit') {
      await _mediaKitPlayer.play();
    } else {
      await _justPlayer.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_activePlayer == 'media_kit') {
      await _mediaKitPlayer.pause();
    } else {
      await _justPlayer.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_activePlayer == 'media_kit') {
      await _mediaKitPlayer.seek(position);
    } else {
      await _justPlayer.seek(position);
    }
  }

  @override
  Future<void> skipToNext() => _justPlayer.seekToNext(); // Assumes local playlist

  @override
  Future<void> skipToPrevious() => _justPlayer.seekToPrevious(); // Assumes local playlist
  
  @override
  Future<void> skipToQueueItem(int index) async {
    if (_activePlayer == 'just') {
      await _justPlayer.seek(Duration.zero, index: index);
    }
    // Not implemented for media_kit as it handles single items for now
  }

  @override
  Future<void> stop() async {
    await _justPlayer.stop();
    await _mediaKitPlayer.stop();
    _activePlayer = 'none';
    await super.stop();
  }


  // ---- Event Transformers ----

  PlaybackState _transformJustAudioEvent(just.PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_justPlayer.hasPrevious) MediaControl.skipToPrevious,
        if (_justPlayer.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        if (_justPlayer.hasNext) MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        just.ProcessingState.idle: AudioProcessingState.idle,
        just.ProcessingState.loading: AudioProcessingState.loading,
        just.ProcessingState.buffering: AudioProcessingState.buffering,
        just.ProcessingState.ready: AudioProcessingState.ready,
        just.ProcessingState.completed: AudioProcessingState.completed,
      }[_justPlayer.processingState]!,
      playing: _justPlayer.playing,
      updatePosition: _justPlayer.position,
      bufferedPosition: _justPlayer.bufferedPosition,
      speed: _justPlayer.speed,
      queueIndex: event.currentIndex,
    );
  }

  PlaybackState _transformMediaKitEvent(bool playing, Duration position, Duration buffering, Duration duration) {
    AudioProcessingState processingState = AudioProcessingState.ready;
    if (playing && buffering == duration) {
        processingState = AudioProcessingState.buffering;
    } else if (!playing && position == Duration.zero) {
        processingState = AudioProcessingState.loading;
    }

    return PlaybackState(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1],
      processingState: processingState,
      playing: playing,
      updatePosition: position,
      bufferedPosition: buffering,
      speed: _mediaKitPlayer.state.rate,
      queueIndex: 0,
    );
  }

  // ---- Helper for YouTube ----
  Future<String> _getYouTubeStreamUrl(String videoId) async {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final originalUrl = streamInfo.url;

      if (originalUrl.queryParameters.containsKey('s')) {
        final cipheredSignature = originalUrl.queryParameters['s']!;
        final solvedSignature = await _decipherService.decipher(cipheredSignature);
        final newQueryParameters = Map<String, String>.from(originalUrl.queryParameters)
          ..remove('s')
          ..addAll({'n': solvedSignature});
        return originalUrl.replace(queryParameters: newQueryParameters).toString();
      } else {
        return originalUrl.toString();
      }
  }

  // --- Methods not implemented for dual-player setup yet ---
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    // Only applying to just_audio for now
    await _justPlayer.setLoopMode(const {
        AudioServiceRepeatMode.none: just.LoopMode.off,
        AudioServiceRepeatMode.one: just.LoopMode.one,
        AudioServiceRepeatMode.all: just.LoopMode.all,
        AudioServiceRepeatMode.group: just.LoopMode.all,
      }[repeatMode] ?? just.LoopMode.off
    );
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    // Only applying to just_audio for now
    await _justPlayer.setShuffleModeEnabled(shuffleMode == AudioServiceShuffleMode.all);
  }
}
