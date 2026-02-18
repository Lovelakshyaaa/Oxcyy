import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';

class SearchProvider with ChangeNotifier {
  List<dynamic> _popularResults = []; // Can hold both Songs and Artists
  List<dynamic> get popularResults => _popularResults;

  TopQueryResult? _topResult;
  TopQueryResult? get topResult => _topResult;

  List<Song> _songResults = [];
  List<Song> get songResults => _songResults;

  List<Artist> _artistResults = [];
  List<Artist> get artistResults => _artistResults;

  bool _isFetchingPopular = false;
  bool get isFetchingPopular => _isFetchingPopular;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  bool _isFetchingMore = false;
  bool get isFetchingMore => _isFetchingMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _currentQuery = '';
  int _currentPage = 1;

  SearchProvider() {
    fetchPopular();
  }

  void _clearAllResults() {
    _topResult = null;
    _songResults.clear();
    _artistResults.clear();
    _errorMessage = null;
  }

  Future<void> fetchPopular() async {
    if (_isFetchingPopular) return;
    _isFetchingPopular = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('https://saavn.me/modules?language=hindi,english'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        final List<dynamic> results = [];

        // Trending Songs (Albums are treated as songs here)
        if (data['trending'] != null && data['trending']['albums'] is List) {
          for (var item in (data['trending']['albums'] as List)) {
            final song = _parseSongItem(item);
            if (song != null) {
              results.add(song);
            }
          }
        }

        // Top Artists
        if (data['artists'] != null && data['artists'] is List) {
          for (var item in (data['artists'] as List)) {
            final artist = _parseArtistItem(item);
            if (artist != null) {
              results.add(artist);
            }
          }
        }

        _popularResults = results;
      } else {
        _errorMessage = "Could not fetch popular results.";
      }
    } catch (e) {
      _errorMessage = "Network error while fetching popular results.";
      print("Popular fetch error: $e");
    } finally {
      _isFetchingPopular = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (query.isEmpty || _isSearching) return;

    _currentQuery = query;
    _currentPage = 1;
    _isSearching = true;
    _clearAllResults();
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('https://saavn.me/search/all?query=${Uri.encodeComponent(query)}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        _parseAllResults(data);
      } else {
        _errorMessage = "API Error: Failed to get search results.";
      }
    } catch (e) {
      _errorMessage = "Network Error: Could not connect to service.";
      print("Search error: $e");
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void _parseAllResults(Map<String, dynamic> data) {
    if (data['topQuery'] != null && data['topQuery']['results'] is List) {
      final topQueryResults = data['topQuery']['results'] as List;
      if (topQueryResults.isNotEmpty) {
        _topResult = _parseTopQueryResult(topQueryResults.first);
      }
    }

    if (data['songs'] != null && data['songs']['results'] is List) {
      final songItems = data['songs']['results'] as List;
      _songResults = songItems.map((item) => _parseSongItem(item)).whereType<Song>().toList();
    }

    if (data['artists'] != null && data['artists']['results'] is List) {
      final artistItems = data['artists']['results'] as List;
      _artistResults = artistItems.map((item) => _parseArtistItem(item)).whereType<Artist>().toList();
    }
  }

  TopQueryResult? _parseTopQueryResult(Map<String, dynamic> item) {
    final type = item['type'];
    if (type == 'artist') {
      return _parseArtistItem(item);
    }
    if (type == 'song') {
      return _parseSongItem(item);
    }
    return null;
  }

  Artist? _parseArtistItem(Map<String, dynamic> item) {
    try {
      return Artist(
        id: item['id'] ?? '',
        name: item['name'] ?? item['title'] ?? 'Unknown Artist',
        imageUrl: _getImageUrl(item['image']),
      );
    } catch (e) {
      print("Error parsing artist item: $e");
      return null;
    }
  }

  Song? _parseSongItem(Map<String, dynamic> item) {
    try {
      String? downloadUrl;
      if (item['downloadUrl'] is List && (item['downloadUrl'] as List).isNotEmpty) {
        final lastUrl = (item['downloadUrl'] as List).last;
        if (lastUrl is Map && lastUrl.containsKey('link')) {
          downloadUrl = lastUrl['link'];
        }
      }
      if (downloadUrl == null) return null;

      String imageUrl = _getImageUrl(item['image']);

      String artist = 'Unknown Artist';
      if (item.containsKey('primaryArtists') && item['primaryArtists'] is String) {
        artist = item['primaryArtists'];
      } else if (item.containsKey('artists') && item['artists'] is List) {
        artist = (item['artists'] as List).map((a) => a['name']).join(', ');
      } else if (item.containsKey('primaryArtists') && item['primaryArtists'] is List) {
        artist = (item['primaryArtists'] as List).map((a) => a['name']).join(', ');
      }

      Duration? duration;
      if (item['duration'] is String) {
        final seconds = int.tryParse(item['duration']);
        if (seconds != null) {
          duration = Duration(seconds: seconds);
        }
      } else if (item['duration'] is num) {
        duration = Duration(seconds: (item['duration'] as num).toInt());
      }

      return Song(
        id: downloadUrl,
        title: item['name'] as String? ?? item['title'] as String? ?? 'Unknown Title',
        artist: artist,
        thumbUrl: imageUrl,
        type: 'saavn',
        duration: duration,
      );
    } catch (e) {
      print("Error parsing song item: $e");
      return null;
    }
  }

  String _getImageUrl(dynamic imageField) {
    if (imageField is List && imageField.isNotEmpty) {
      final imageMap = imageField.firstWhere((i) => i['quality'] == '500x500', orElse: () => imageField.last);
      return imageMap['link'] ?? '';
    }
    return '';
  }

  Future<void> fetchMoreResults() async {
    if (_currentQuery.isEmpty || _isFetchingMore || _isSearching) return;

    _isFetchingMore = true;
    notifyListeners();

    _currentPage++;
    try {
      final response = await http.get(Uri.parse('https://saavn.me/search/songs?query=${Uri.encodeComponent(_currentQuery)}&page=$_currentPage'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        final List<Song> moreResults = [];
        if (data['results'] is List) {
          final apiResults = data['results'] as List;
          for (var item in apiResults) {
            final song = _parseSongItem(item);
            if (song != null) {
              moreResults.add(song);
            }
          }
          _songResults.addAll(moreResults);
        }
      }
    } catch (e) {
      print("Fetch more error: $e");
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _clearAllResults();
    notifyListeners();
  }
}
