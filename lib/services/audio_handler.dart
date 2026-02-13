import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:rxdart/rxdart.dart';
import '../utils/clients.dart';
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
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  
  late final YoutubeExplode _youtubeVr;
  late final YoutubeExplode _youtubeAndroid;

  final _mediaItemStreamController = BehaviorSubject<MediaItem?>.seeded(null);

  MyAudioHandler() {
    _youtubeVr = YoutubeExplode(createAndroidVrClient());
    _youtubeAndroid = YoutubeExplode(createAndroidClient());
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setAudioSource(_playlist, preload: false);

    // Propagate player events to the UI
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Report the current media item
    _player.sequenceStateStream.listen((sequenceState) {
      final currentItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (currentItem != null) mediaItem.add(currentItem);
    });
  }

  Future<AudioSource> _createAudioSource(MediaItem item) async {
    if (item.genre == 'youtube') {
      try {
        var manifest = await _youtubeVr.videos.streamsClient.getManifest(item.id);
        var url = manifest.audioOnly.withHighestBitrate().url;
        return AudioSource.uri(url, tag: item);
      } catch (e) {
        print('VR client failed for ${item.id}, trying Android client...');
        try {
          var manifest = await _youtubeAndroid.videos.streamsClient.getManifest(item.id);
          var url = manifest.audioOnly.withHighestBitrate().url;
          return AudioSource.uri(url, tag: item);
        } catch (e) {
          print('Android client also failed for ${item.id}: $e');
          throw Exception('Could not get stream URL for ${item.id}');
        }
      }
    } else {
      return AudioSource.uri(Uri.parse(item.id), tag: item);
    }
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    try {
      final source = await _createAudioSource(item);
      await _playlist.add(source);
      queue.add(List.from(queue.value)..add(item));
    } catch (e) {
      print("Error adding queue item: $e");
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    try {
      final audioSources = await Future.wait(newQueue.map(_createAudioSource));
      await _playlist.clear();
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
    return super.stop();
  }
  
  @override
  Future<void> onClose() {
    _player.dispose();
    _youtubeVr.close();
    _youtubeAndroid.close();
    return super.onClose();
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
    );
  }
}
