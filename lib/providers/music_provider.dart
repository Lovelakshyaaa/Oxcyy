import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:oxcy/models/search_models.dart';

class MusicProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _baseUrl = "https://music-three-woad.vercel.app";

  Song? _currentSong;
  Song? get currentSong => _currentSong;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  Duration _position = Duration.zero;
  Duration get position => _position;

  MusicProvider() {
    _audioPlayer.playerStateStream.listen((playerState) {
      _isPlaying = playerState.playing;
      if (playerState.processingState == ProcessingState.completed) {
        _position = Duration.zero;
        _isPlaying = false;
      }
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
  }

  Future<void> play(Song song) async {
    _currentSong = song;
    notifyListeners();

    try {
      if (song.downloadUrl == null || song.downloadUrl!.isEmpty) {
        // Fetch the song details to get the download URL
        final response = await http.get(Uri.parse('$_baseUrl/song?id=${song.id}'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body)['data'];
          // The response for a single song might be a list
          final songData = data is List ? data[0] : data;
          final downloadUrl = _getDownloadUrl(songData['downloadUrl']);

          if (downloadUrl != null) {
            song.downloadUrl = downloadUrl;
          } else {
            print('Error: Download URL not found in API response for song id ${song.id}');
            return; // Can't play without a URL
          }
        } else {
          print('Error: Failed to fetch song details (status code: ${response.statusCode})');
          return;
        }
      }

      if (song.downloadUrl != null) {
        await _audioPlayer.setUrl(song.downloadUrl!);
        _audioPlayer.play();
      }
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  String? _getDownloadUrl(dynamic urlField) {
    if (urlField is List && urlField.isNotEmpty) {
      // Look for the last URL which is often the highest quality
      return urlField.last['link'];
    }
    if (urlField is String) {
      return urlField;
    }
    return null;
  }

  void pause() {
    _audioPlayer.pause();
  }

  void resume() {
    _audioPlayer.play();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
