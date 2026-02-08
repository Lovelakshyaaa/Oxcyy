import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.oxcy.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    // 1. Broadcast Playback State (Playing/Paused/Buffering)
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // 2. Broadcast Media Item Updates (Duration!)
    // This fixes the "No Duration" bug
    _player.durationStream.listen((duration) {
      if (duration != null && mediaItem.value != null) {
        final newMediaItem = mediaItem.value!.copyWith(duration: duration);
        mediaItem.add(newMediaItem);
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
      // ⚠️ ROBUST HYBRID LOGIC
      if (item.id.startsWith('http')) {
        // Online (YouTube)
        await _player.setUrl(item.id);
      } else {
        // Local File - The Fix for "Nothing Plays"
        // usage of Uri.file ensures correct scheme handling on Android
        await _player.setAudioSource(AudioSource.uri(Uri.file(item.id)));
      }
      await _player.play();
    } catch (e) {
      print("Handler Error: $e");
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
