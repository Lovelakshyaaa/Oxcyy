import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
  final YoutubeExplode _youtube = YoutubeExplode();

  MyAudioHandler() {
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
    _player.playbackEventStream.map(_transformEvent).listen(playbackState.add);
  }

  void _listenForCurrentMediaItem() {
    _player.sequenceStateStream.listen((sequenceState) {
      final currentItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (currentItem != null) mediaItem.add(currentItem);
    });
  }

  // ---------- QueueHandler implementation ----------
  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    queue.add(newQueue); // updates the public `queue` stream
    await _playlist.clear();

    for (final item in newQueue) {
      try {
        AudioSource source;
        if (item.genre == 'youtube') {
          final manifest = await _youtube.videos.streamsClient.getManifest(item.id);
          final audioUrl = manifest.audioOnly.withHighestBitrate().url;
          source = AudioSource.uri(audioUrl, tag: item);
        } else {
          // Local file – item.id must be the content:// URI
          source = AudioSource.uri(Uri.parse(item.id), tag: item);
        }
        _playlist.add(source);
      } catch (e) {
        print('Failed to add ${item.title}: $e');
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _playlist.children.length) return;
    await _player.seek(Duration.zero, index: index);
    play(); // auto-play after skip
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  // ---------- Standard controls ----------
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
  }

  // ---------- Transform just_audio events into audio_service playback state ----------
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1],
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
      
