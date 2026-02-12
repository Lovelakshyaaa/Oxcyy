import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart'; 

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

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  // ⚠️ THE FIX: A managed playlist container
  final _playlist = ConcatenatingAudioSource(children: []);

  MyAudioHandler() {
    _init();
    
    // Broadcast playback events
    _player.playbackEventStream.map(_transformEvent).listen((playbackEvent) {
      playbackState.add(playbackEvent);
    });
    
    // ⚠️ THE FIX: Automatically update MediaItem from the player's current tag
    _player.sequenceStateStream.listen((sequenceState) {
      final currentItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (currentItem != null) {
        mediaItem.add(currentItem);
      }
    });
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // ⚠️ THE FIX: Initialize the player with the playlist ONCE
    // We will never call setAudioSource again; we will just modify the playlist.
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      print("Error setting source: $e");
    }
    
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
            _player.play();
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
    // Notify UI immediately
    mediaItem.add(item); 
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
    ));

    try {
      AudioSource source;
      if (item.id.startsWith('http')) {
        source = AudioSource.uri(
          Uri.parse(item.id),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'},
          tag: item, // ⚠️ Tagging is crucial for sequenceStateStream
        );
      } else {
        source = LockCachingAudioSource(
          Uri.parse(item.id),
          tag: item, // ⚠️ Tagging is crucial
        );
      }
      
      // ⚠️ THE FIX: Manipulate the playlist instead of replacing the root source
      await _playlist.clear();
      await _playlist.add(source);
      await _player.play();
      
    } catch (e) {
      print("Handler Error: $e");
      String errorMsg = "DEBUG_ERR: $e";
      await Clipboard.setData(ClipboardData(text: errorMsg));
      
      mediaItem.add(item.copyWith(
        title: "ERR: ${e.toString().split(':').last.trim().substring(0, 15)}", 
        artist: "Debug: ${e.toString().substring(0, 30)}",
      ));
      
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        errorMessage: errorMsg,
        playing: false,
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
