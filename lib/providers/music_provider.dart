import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:just_audio/just_audio.dart';

// 1. Custom Model to hold API Data
class Song {
  final String id;
  final String title;
  final String artist;
  final String thumbUrl;

  Song({required this.id, required this.title, required this.artist, required this.thumbUrl});
}

class MusicProvider with ChangeNotifier {
  // 2. YOUR API KEY
  static const String _apiKey = "AIzaSyBXc97B045znooQD-NDPBjp8SluKbDSbmc";
  
  final _yt = YoutubeExplode();
  final _player = AudioPlayer();
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  Song? _currentSong;
  Song? get currentSong => _currentSong;
  
  AudioPlayer get player => _player;

  // 3. NEW: Search using Official API (Instant Results)
  Future<List<Song>> search(String query) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&maxResults=15&key=$_apiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> items = data['items'];
        
        List<Song> songs = items.map((item) {
          return Song(
            id: item['id']['videoId'],
            title: item['snippet']['title'],
            artist: item['snippet']['channelTitle'],
            thumbUrl: item['snippet']['thumbnails']['high']['url'],
          );
        }).toList();
        
        _isLoading = false;
        notifyListeners();
        return songs;
      }
    } catch (e) {
      print("API Error: $e");
    }
    
    _isLoading = false;
    notifyListeners();
    return [];
  }

  // 4. Play Logic (Uses Version 3.0.5 features)
  Future<void> play(Song song) async {
    _currentSong = song;
    notifyListeners();

    try {
      // Get the actual audio stream using the ID we found
      var manifest = await _yt.videos.streamsClient.getManifest(song.id);
      var audioUrl = manifest.audioOnly.withHighestBitrate().url;
      
      await _player.setUrl(audioUrl.toString());
      _player.play();
    } catch (e) {
      print("Audio Error: $e");
    }
  }
}
