import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';

class SearchProvider with ChangeNotifier {
  List<Song> _popularSongs = [];
  List<Song> get popularSongs => _popularSongs;

  // New data structures for categorized search
  TopQueryResult? _topResult;
  TopQueryResult? get topResult => _topResult;

  List<Song> _songResults = [];
  List<Song> get songResults => _songResults;

  List<Artist> _artistResults = [];
  List<Artist> get artistResults => _artistResults;

  List<Album> _albumResults = [];
  List<Album> get albumResults => _albumResults;

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
    fetchPopularSongs();
  }

  void _clearAllResults() {
    _topResult = null;
    _songResults.clear();
    _artistResults.clear();
    _albumResults.clear();
    _errorMessage = null;
  }

  Future<void> search(String query) async {
    if (query.isEmpty || _isSearching) return;

    _currentQuery = query;
    _currentPage = 1;
    _isSearching = true;
    _clearAllResults();
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('https://music-three-woad.vercel.app/search/all?q=${Uri.encodeComponent(query)}'));

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
     // Top Query
    if (data['topQuery'] != null && data['topQuery']['results'] is List) {
      final topQueryResults = data['topQuery']['results'] as List;
      if (topQueryResults.isNotEmpty) {
        _topResult = _parseTopQueryResult(topQueryResults.first);
      }
    }

    // Songs
    if (data['songs'] != null && data['songs']['results'] is List) {
      final songItems = data['songs']['results'] as List;
      _songResults = songItems.map((item) => _parseSongItem(item)).where((s) => s != null).cast<Song>().toList();
    }

    // Artists
    if (data['artists'] != null && data['artists']['results'] is List) {
      final artistItems = data['artists']['results'] as List;
      _artistResults = artistItems.map((item) => _parseArtistItem(item)).where((a) => a != null).cast<Artist>().toList();
    }
  }

  Future<void> fetchMoreResults() async {
    if (_currentQuery.isEmpty || _isFetchingMore || _isSearching) return;

    _isFetchingMore = true;
    notifyListeners();

    _currentPage++;
    try {
        final response = await http.get(Uri.parse('https://music-three-woad.vercel.app/search/songs?q=${Uri.encodeComponent(_currentQuery)}&page=$_currentPage'));

        if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['data'] != null && data['data']['results'] is List) {
                final apiResults = data['data']['results'] as List;
                final moreSongs = apiResults.map((item) => _parseSongItem(item)).where((s) => s != null).cast<Song>().toList();
                _songResults.addAll(moreSongs);
            }
        }
    } catch (e) {
        print("Fetch more error: $e");
    } finally {
        _isFetchingMore = false;
        notifyListeners();
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
      String? downloadUrl = _getDownloadUrl(item['downloadUrl']);
      if (downloadUrl == null) return null; // Can't play it, don't show it

      String artistName = 'Unknown Artist';
      if (item['primaryArtists'] is String && (item['primaryArtists'] as String).isNotEmpty) {
        artistName = item['primaryArtists'];
      } else if (item['primaryArtists'] is List && (item['primaryArtists'] as List).isNotEmpty) {
         artistName = (item['primaryArtists'] as List).map((artist) => artist['name'] as String? ?? '').join(', ');
      }

      return Song(
        id: downloadUrl,
        title: item['name'] ?? item['title'] ?? 'Unknown Title',
        artist: artistName,
        thumbUrl: _getImageUrl(item['image']),
        type: 'saavn',
        duration: item['duration'] != null ? Duration(seconds: int.parse(item['duration'])) : null,
      );
    } catch (e) {
      print("Error parsing song item: $e");
      return null;
    }
  }

  String _getImageUrl(dynamic imageField) {
      if (imageField is List && imageField.isNotEmpty) {
          final imageMap = imageField.lastWhere((i) => i['quality'] == '500x500', orElse: () => imageField.last);
          return imageMap['link'] ?? '';
      }
      return '';
  }

  String? _getDownloadUrl(dynamic urlField) {
    if (urlField is List && urlField.isNotEmpty) {
      final urlMap = urlField.lastWhere((u) => u['quality'] == '320kbps', orElse: () => urlField.last);
      return urlMap['link'];
    }
    return null;
  }

  // Keep the original fetchPopularSongs and clearSearch as they are still useful
  Future<void> fetchPopularSongs() async {
    if (_isFetchingPopular) return;
    _isFetchingPopular = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('https://music-three-woad.vercel.app/get/trending?type=song'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Song> trendResults = [];
        if (data['data'] is List) {
          for (var item in (data['data'] as List)) {
            final song = _parseSongItem(item);
            if (song != null) {
              trendResults.add(song);
            }
          }
        }
        _popularSongs = trendResults;
      } else {
        _errorMessage = "Could not fetch trending songs.";
      }
    } catch (e) {
      _errorMessage = "Network error while fetching trending songs.";
    } finally {
      _isFetchingPopular = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _clearAllResults();
    notifyListeners();
  }
}
