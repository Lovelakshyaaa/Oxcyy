import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';

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
  final _playlist = ConcatenatingAudioSource(children: []);
  YtFlutterMusicapi? _yt;

  MyAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _yt = await YtFlutterMusicapi().initialize();

    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Propagate all events from the audio player to AudioService clients.
    _player.sequenceStateStream.listen((sequenceState) {
      final mediaItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (mediaItem != null) {
        this.mediaItem.add(mediaItem);
      }
      if (sequenceState != null) {
        queue.add(sequenceState.sequence.map((s) => s.tag as MediaItem).toList());
      }
    });

    // Any errors from the audio player...
    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace st) {
      if (e is PlayerException) {
        print('Error: ${e.message}');
      } else {
        print('An error occurred: $e');
      }
    });

    await _player.setAudioSource(_playlist, preload: false);
  }

  Future<AudioSource> _createAudioSource(MediaItem item) async {
    if (item.genre == 'youtube') {
      try {
        var url = await _yt!.getAudioUrl(item.extras!['id']);
        return AudioSource.uri(Uri.parse(url), tag: item);
      } catch (e) {
        print('Error getting stream URL for ${item.id}: $e');
        throw Exception('Could not get stream URL for ${item.id}');
      }
    } else {
      return AudioSource.uri(Uri.parse(item.id), tag: item);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        _player.setLoopMode(LoopMode.all);
        break;
    }
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    try {
      final source = await _createAudioSource(item);
      await _playlist.add(source);
      final newQueue = queue.value..add(item);
      queue.add(newQueue);
    } catch (e) {
      print("Error adding queue item: $e");
    }
  }
  
    @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    // If it's a YouTube video, we need to create a source with the fetched URL
    if (mediaItem.genre == 'youtube') {
      try {
        final audioSource = await _createAudioSource(mediaItem);
        // Stop current playback
        await _player.stop();
        // Clear the existing playlist
        await _playlist.clear();
        // Add the new source and play it
        await _playlist.add(audioSource);
        queue.add([mediaItem]);
        await _player.play();
      } catch (e) {
        print("Error playing YouTube media item: $e");
      }
    } else {
      // For local files, we can just play them by their ID (URI)
      final index = queue.value.indexWhere((item) => item.id == mediaItem.id);
      if (index != -1) {
        await skipToQueueItem(index);
        await play();
      }
    }
  }


  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    try {
      await _playlist.clear();
      final audioSources = await Future.wait(newQueue.map(_createAudioSource));
      await _playlist.addAll(audioSources);
      queue.add(newQueue);
    } catch (e) {
      print("Error updating queue: $e");
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    await _player.seek(Duration.zero, index: index);
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
    await _player.dispose();
    _yt?.close();
    return super.stop();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.hasPrevious) MediaControl.skipToPrevious else MediaControl.play,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        if (_player.hasNext) MediaControl.skipToNext else MediaControl.play,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
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
      repeatMode: const {
        LoopMode.off: AudioServiceRepeatMode.none,
        LoopMode.one: AudioServiceRepeatMode.one,
        LoopMode.all: AudioServiceRepeatMode.all,
      }[_player.loopMode]!,
    );
  }
}
