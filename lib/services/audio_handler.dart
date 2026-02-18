import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as just;
import 'package:rxdart/rxdart.dart';

// The simplified AudioHandler for local files only.
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
  final _player = just.AudioPlayer();
  final _playlist =
      just.ConcatenatingAudioSource(useLazyPreparation: true, children: []);

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen to state changes from the player and pipe them to the UI
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Propagate all events from the audio player to AudioService clients.
    _player.sequenceStateStream.listen((sequenceState) {
      if (sequenceState != null) {
        final currentItem = sequenceState.currentSource?.tag as MediaItem?;
        if (currentItem != null) mediaItem.add(currentItem);

        final currentQueue =
            sequenceState.sequence.map((s) => s.tag as MediaItem).toList();
        if (queue.value != currentQueue) {
          queue.add(currentQueue);
        }
      }
    });

    // Set the initial audio source
    try {
      await _player.setAudioSource(_playlist, preload: false);
    } catch (e) {
      print("Error setting initial audio source: $e");
    }
  }

  // ---- Queue Management ----

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    final audioSources = newQueue
        .map((item) => just.AudioSource.uri(Uri.parse(item.id), tag: item))
        .toList();
    await _playlist.clear();
    await _playlist.addAll(audioSources);
    queue.add(newQueue);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  // ---- Playback Controls ----

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    // This is now only for local files.
    final index = queue.value.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      await skipToQueueItem(index);
    }
  }

  // ---- Event Transformer ----

  PlaybackState _transformEvent(just.PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.hasPrevious) MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        if (_player.hasNext) MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        just.ProcessingState.idle: AudioProcessingState.idle,
        just.ProcessingState.loading: AudioProcessingState.loading,
        just.ProcessingState.buffering: AudioProcessingState.buffering,
        just.ProcessingState.ready: AudioProcessingState.ready,
        just.ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  // ---- Repeat and Shuffle ----

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(const {
          AudioServiceRepeatMode.none: just.LoopMode.off,
          AudioServiceRepeatMode.one: just.LoopMode.one,
          AudioServiceRepeatMode.all: just.LoopMode.all,
          AudioServiceRepeatMode.group: just.LoopMode.all,
        }[repeatMode] ??
        just.LoopMode.off);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player
        .setShuffleModeEnabled(shuffleMode == AudioServiceShuffleMode.all);
  }
}
