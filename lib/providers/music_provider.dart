
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

class MusicProvider with ChangeNotifier {
  final YoutubeExplode _youtubeExplode = YoutubeExplode();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Video> _searchResults = [];
  Video? _currentVideo;
  bool _isLoading = false;
  bool _isPlaying = false;

  List<Video> get searchResults => _searchResults;
  Video? get currentVideo => _currentVideo;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;
  AudioPlayer get audioPlayer => _audioPlayer;

  MusicProvider() {
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _isPlaying = false;
      } else {
        _isPlaying = playerState.playing;
      }
      notifyListeners();
    });
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      var searchList = await _youtubeExplode.search.getVideos(query);
      _searchResults = searchList.toList();
    } catch (e) {
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> play(Video video) async {
    _currentVideo = video;
    _isLoading = true;
    notifyListeners();

    try {
      var manifest = await _youtubeExplode.videos.streamsClient.getManifest(video.id);
      var audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      var streamUrl = audioStreamInfo.url;

      await _audioPlayer.setUrl(streamUrl.toString());
      _audioPlayer.play();
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void pause() {
    _audioPlayer.pause();
  }

  void resume() {
    _audioPlayer.play();
  }

  @override
  void dispose() {
    _youtubeExplode.close();
    _audioPlayer.dispose();
    super.dispose();
  }
}
