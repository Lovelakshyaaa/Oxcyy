import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart'; // <--- MANDATORY IMPORT

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.oxcy.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      // ⚠️ REQUIRED FOR ANDROID 13+ CONTROLS
      androidShowNotificationBadge: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    _init();
    
    // Broadcast playback events to UI
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    
    // Sync duration
    _player.durationStream.listen((duration) {
       final index = _player.currentIndex;
       final newDuration = duration ?? Duration.zero;
       if (mediaItem.value != null && newDuration > Duration.zero) {
         mediaItem.add(mediaItem.value!.copyWith(duration: newDuration));
       }
    });
  }

  Future<void> _init() async {
    // ⚠️ THE MISSING LINK: Audio Session Management
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    
    // Handle unplugging headphones / call interruptions
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            _player.pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _player.setVolume(1.0);
            break;
          case AudioInterruptionType.pause:
            _player.play(); // Auto-resume
            break;
          case AudioInterruptionType.unknown:
            break;
        }
      }
    });
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    try {
      if (item.id.startsWith('http')) {
        // ⚠️ GATEKEPT TIP: Headers to bypass 403/Throttling
        await _player.setAudioSource(AudioSource.uri(
          Uri.parse(item.id),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'},
        ));
      } else {
        await _player.setAudioSource(AudioSource.uri(Uri.file(item.id)));
      }
      await _player.play();
    } catch (e) {
      print("Handler Error: $e");
      // Notify UI of error state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
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
    );
  }
}
