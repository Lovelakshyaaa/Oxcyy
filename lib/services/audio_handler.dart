import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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

  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  MyAudioHandler() {
    _youtubeVr = YoutubeExplode(createAndroidVrClient());
    _youtubeAndroid = YoutubeExplode(createAndroidClient());
    _init();
    _notifyPlaybackEvents();
    _listenForCurrentMediaItem();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setAudioSource(_playlist, preload: false);
  }

  void _notifyPlaybackEvents() {
    _player.playbackEventStream
        .throttleTime(const Duration(milliseconds: 100))
        .map(_transformEvent)
        .listen(playbackState.add, onError: _handleStreamError);
  }

  void _listenForCurrentMediaItem() {
    _player.sequenceStateStream
        .throttleTime(const Duration(milliseconds: 100))
        .listen((sequenceState) {
      final currentItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (currentItem != null) mediaItem.add(currentItem);
    }, onError: _handleStreamError);
  }

  void _handleStreamError(error, stackTrace) {
    print('Stream error: $error');
    _consecutiveErrors++;
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      stop();
    }
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue);
    await _playlist.clear();
    _consecutiveErrors = 0;

    for (final item in newQueue) {
      try {
        AudioSource source;
        if (item.genre == 'youtube') {
          // Try VR first, then Android
          source = await _getYoutubeSource(item);
        } else {
          source = AudioSource.uri(Uri.parse(item.id), tag: item);
        }
        await _playlist.add(source);
      } catch (e) {
        print('Failed to add ${item.title}: $e');
        // Optionally add a dummy silent source to keep queue position
      }
    }
  }

  Future<AudioSource> _getYoutubeSource(MediaItem item) async {
    try {
      final manifest = await _youtubeVr.videos.streamsClient.getManifest(item.id);
      final audioUrl = manifest.audioOnly.withHighestBitrate().url;
      return AudioSource.uri(audioUrl, tag: item);
    } catch (e) {
      print('VR client failed, trying Android...');
      final manifest = await _youtubeAndroid.videos.streamsClient.getManifest(item.id);
      final audioUrl = manifest.audioOnly.withHighestBitrate().url;
      return AudioSource.uri(audioUrl, tag: item);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.children.length) return;
    await _player.seek(Duration.zero, index: index);
    play();
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    _consecutiveErrors = 0;
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    final playing = _player.playing;
    final queueSize = _playlist.children.length;
    return PlaybackState(
      controls: [
        if (queueSize > 1) MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        if (queueSize > 1) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: queueSize > 1 ? [0, 1, 2] : [0, 1],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
