import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:oxcy/services/youtube_audio_source.dart';

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
  final AudioPlayer _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(useLazyPreparation: true, children: []);

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    _player.sequenceStateStream.listen((sequenceState) {
      final mediaItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (mediaItem != null) this.mediaItem.add(mediaItem);
      if (sequenceState != null) {
        final currentQueue = sequenceState.sequence.map((s) => s.tag as MediaItem).toList();
        if (queue.value != currentQueue) {
          queue.add(currentQueue);
        }
      }
    });

    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace st) {
      print('Player Error: $e');
    });

    try {
      await _player.setAudioSource(_playlist, preload: false);
    } catch (e) {
      print("Error setting initial audio source: $e");
    }
  }

  Future<AudioSource> _createAudioSource(MediaItem item) async {
    if (item.genre == 'youtube') {
      return await YoutubeAudioSource.create(item.id, tag: item);
    } else {
      return AudioSource.uri(Uri.parse(item.id), tag: item);
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    try {
      await _player.stop();
      await _playlist.clear();
      final audioSources = await Future.wait(newQueue.map(_createAudioSource).toList());
      await _playlist.addAll(audioSources);
      queue.add(newQueue);
    } catch (e) {
      print("Error updating queue: $e");
    }
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
      try {
        await _player.stop();
        await _playlist.clear();
        final source = await _createAudioSource(mediaItem);
        await _playlist.add(source);
        queue.add([mediaItem]);
        await _player.play();
      } catch (e) {
        print("Error playing media item: $e");
      }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(repeatMode.toLoopMode());
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all;
    await _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      await _player.shuffle();
    }
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

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
    return super.stop();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (queue.value.length > 1 && _player.hasPrevious) MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        if (queue.value.length > 1 && _player.hasNext) MediaControl.skipToNext,
      ],
      systemActions: const { MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
      repeatMode: playbackState.value.repeatMode,
      shuffleMode: playbackState.value.shuffleMode,
    );
  }
}

extension on AudioServiceRepeatMode {
  LoopMode toLoopMode() => const {
        AudioServiceRepeatMode.none: LoopMode.off,
        AudioServiceRepeatMode.one: LoopMode.one,
        AudioServiceRepeatMode.all: LoopMode.all,
        AudioServiceRepeatMode.group: LoopMode.all,
      }[this] ??
      LoopMode.off;
}
