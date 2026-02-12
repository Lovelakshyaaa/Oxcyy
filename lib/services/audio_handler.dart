import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
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

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);
  final _youtube = YoutubeExplode();

  MyAudioHandler() {
    _init();
    _notifyAudioHandlerAboutPlaybackEvents();
    _listenForCurrentSongIndexChanges();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    try {
      // Use the playlist as the player's source
      await _player.setAudioSource(_playlist, preload: false);
    } catch (e) {
      print("Error setting audio source: $e");
    }

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          _player.setVolume(0.5);
        } else {
          pause();
        }
      } else {
        if (event.type == AudioInterruptionType.duck) {
          _player.setVolume(1.0);
        } else {
          play();
        }
      }
    });
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.map(_transformEvent).listen((playbackState) {
      this.playbackState.add(playbackState);
    });
  }

  void _listenForCurrentSongIndexChanges() {
    _player.sequenceStateStream.listen((sequenceState) {
      final currentItem = sequenceState?.currentSource?.tag as MediaItem?;
      if (currentItem != null) {
        mediaItem.add(currentItem);
      }
    });
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.loading,
    ));

    try {
      // *** THE FIX FOR STUCK PLAYER ***
      // Stop the player and clear the playlist before adding a new item.
      await _player.stop();
      await _playlist.clear();

      AudioSource source;
      if (item.genre == 'youtube') {
        var manifest = await _youtube.videos.streamsClient.getManifest(item.id);
        var audioUrl = manifest.audioOnly.withHighestBitrate().url;
        source = AudioSource.uri(audioUrl, tag: item);
      } else {
        // For local files, the ID is already the URI string.
        source = AudioSource.uri(Uri.parse(item.id), tag: item);
      }
      
      await _playlist.add(source);
      await _player.play();

    } catch (e) {
      print("Handler Error: $e");
      String errorMsg = "DEBUG_ERR: $e";
      await Clipboard.setData(ClipboardData(text: errorMsg));
      mediaItem.add(item.copyWith(
        title: "ERR: Playback Failed",
        artist: "Check logs for details",
      ));
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: errorMsg,
      ));
    }
  }

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
