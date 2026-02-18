import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oxcy/models/search_models.dart'; // We will reuse this for Song and Artist for now
import 'package:oxcy/providers/music_provider.dart';



class Playlist {
  final String id;
  final String title;
  final String imageUrl;
  final String? subtitle;

  Playlist({required this.id, required this.title, required this.imageUrl, this.subtitle});
}

class Chart {
  final String id;
  final String title;
  final String imageUrl;

  Chart({required this.id, required this.title, required this.imageUrl});
}

// --- Provider ---

class MusicData with ChangeNotifier {
  final String _baseUrl = "https://music-three-woad.vercel.app";

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Holds all the data from the /modules endpoint
  Map<String, List<dynamic>> _modules = {};
  Map<String, List<dynamic>> get modules => _modules;

  // Holds search results
  bool _isSearching = false;
  bool get isSearching => _isSearching;
  List<dynamic> _searchResults = [];
  List<dynamic> get searchResults => _searchResults;

  MusicData() {
    fetchLaunchData();
  }

  Future<void> fetchLaunchData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/modules'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        _modules.clear(); // Clear old data

        // --- Parse all modules from the endpoint ---
        if (data['trending'] != null && data['trending']['songs'] is List) {
          _modules['trending_songs'] = (data['trending']['songs'] as List)
              .map((item) => buildSong(item))
              .whereType<Song>()
              .toList();
        }
        if (data['trending'] != null && data['trending']['albums'] is List) {
          _modules['trending_albums'] = (data['trending']['albums'] as List)
              .map((item) => buildAlbum(item))
              .whereType<Album>()
              .toList();
        }
        if (data['playlists'] != null && data['playlists'] is List) {
          _modules['playlists'] = (data['playlists'] as List)
              .map((item) => buildPlaylist(item))
              .whereType<Playlist>()
              .toList();
        }
        if (data['charts'] != null && data['charts'] is List) {
          _modules['charts'] = (data['charts'] as List)
              .map((item) => buildChart(item))
              .whereType<Chart>()
              .toList();
        }
         if (data['albums'] != null && data['albums'] is List) {
          _modules['albums'] = (data['albums'] as List)
              .map((item) => buildAlbum(item))
              .whereType<Album>()
              .toList();
        }

      } else {
        _errorMessage = "Failed to load essential app data. Please restart.";
      }
    } catch (e) {
      _errorMessage = "A network error occurred. Please check your connection.";
      print("Launch data fetch error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      _searchResults.clear();
      notifyListeners();
      return;
    }
    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        _searchResults.clear();
        if (data['results'] is List) {
          _searchResults = (data['results'] as List)
              .map((item) => _parseSearchResultItem(item))
              .whereType<dynamic>()
              .toList();
        }
      } else {
        _errorMessage = "Search failed.";
      }
    } catch (e) {
      _errorMessage = "Network error during search.";
      print("Search error: $e");
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults.clear();
    notifyListeners();
  }

 // --- PARSING HELPERS ---

  dynamic _parseSearchResultItem(Map<String, dynamic> item) {
    switch (item['type']) {
      case 'song':
        return buildSong(item);
      case 'artist':
        return buildArtist(item);
      case 'album':
        return buildAlbum(item);
      case 'playlist':
        return buildPlaylist(item);
      default:
        return null;
    }
  }

  Song? buildSong(Map<String, dynamic> item) {
    try {
      if (item['id'] == null) return null;
      final downloadUrl = _getDownloadUrl(item['downloadUrl']);
      if (downloadUrl == null) return null;

      return Song(
        id: downloadUrl,
        title: item['name'] ?? 'Unknown Title',
        artist: _getArtistName(item),
        thumbUrl: _getImageUrl(item['image']),
        type: 'song',
        duration: _getDuration(item['duration']),
      );
    } catch (e) {
      print("Error parsing song: $e");
      return null;
    }
  }

  Artist? buildArtist(Map<String, dynamic> item) {
    try {
      if (item['id'] == null) return null;
      return Artist(
        id: item['id'],
        name: item['name'] ?? 'Unknown Artist',
        imageUrl: _getImageUrl(item['image']),
      );
    } catch (e) {
      print("Error parsing artist: $e");
      return null;
    }
  }

   Album? buildAlbum(Map<String, dynamic> item) {
    try {
      if (item['id'] == null) return null;
      return Album(
        id: item['id'],
        title: item['name'] ?? item['title'] ?? 'Unknown Album',
        imageUrl: _getImageUrl(item['image']),
        subtitle: item['subtitle'] ?? item['year']?.toString(),
      );
    } catch (e) {
      print("Error parsing album: $e");
      return null;
    }
  }

  Playlist? buildPlaylist(Map<String, dynamic> item) {
    try {
      if (item['id'] == null) return null;
      return Playlist(
        id: item['id'],
        title: item['title'] ?? 'Unknown Playlist',
        imageUrl: _getImageUrl(item['image']),
        subtitle: item['subtitle'],
      );
    } catch (e) {
      print("Error parsing playlist: $e");
      return null;
    }
  }

  Chart? buildChart(Map<String, dynamic> item) {
    try {
      if (item['id'] == null) return null;
      return Chart(
        id: item['id'],
        title: item['title'] ?? 'Unknown Chart',
        imageUrl: _getImageUrl(item['image']),
      );
    } catch (e) {
      print("Error parsing chart: $e");
      return null;
    }
  }

  // --- UTILITY PARSERS ---

  String _getArtistName(Map<String, dynamic> item) {
    if (item['primaryArtists'] is String && (item['primaryArtists'] as String).isNotEmpty) return item['primaryArtists'];
    if (item['primaryArtists'] is List && (item['primaryArtists'] as List).isNotEmpty) {
      return (item['primaryArtists'] as List).map((a) => a['name']).join(', ');
    }
    return 'Unknown Artist';
  }

  Duration? _getDuration(dynamic duration) {
    if (duration is String) {
      final seconds = int.tryParse(duration);
      return seconds != null ? Duration(seconds: seconds) : null;
    }
    if (duration is num) return Duration(seconds: duration.toInt());
    return null;
  }

  String _getImageUrl(dynamic imageField) {
    if (imageField is List && imageField.isNotEmpty) {
      final imageMap = imageField.firstWhere((i) => i['quality'] == '500x500', 
                        orElse: () => imageField.firstWhere((i) => i['quality'] == '150x150', 
                        orElse: () => imageField.last));
      return imageMap['link'] ?? '';
    }
    return '';
  }

  String? _getDownloadUrl(dynamic urlField) {
     if (urlField is List && urlField.isNotEmpty) {
      final urlMap = urlField.firstWhere((u) => u['quality'] == '320kbps', 
                    orElse: () => urlField.firstWhere((u) => u['quality'] == '160kbps', 
                    orElse: () => urlField.last));
      return urlMap['link'];
    }
    return null;
  }
}
