import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oxcy/providers/music_provider.dart'; // We still need the Song model

class SearchProvider with ChangeNotifier {
  List<Song> _popularSongs = [];
  List<Song> get popularSongs => _popularSongs;

  List<Song> _searchResults = [];
  List<Song> get searchResults => _searchResults;

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
      print("Trending fetch error: $e");
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
    _searchResults.clear();
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('https://music-three-woad.vercel.app/search/songs?q=${Uri.encodeComponent(query)}&page=$_currentPage'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data']['results'] is List) {
          final apiResults = data['data']['results'] as List;
          for (var item in apiResults) {
            final song = _parseSongItem(item);
            if (song != null) {
              _searchResults.add(song);
            }
          }
        }
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

  Future<void> fetchMoreResults() async {
    if (_currentQuery.isEmpty || _isFetchingMore || _isSearching) return;

    _isFetchingMore = true;
    notifyListeners();

    _currentPage++;
    try {
      final response = await http.get(Uri.parse('https://music-three-woad.vercel.app/search/songs?q=${Uri.encodeComponent(_currentQuery)}&page=$_currentPage'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Song> moreResults = [];
        if (data['data'] != null && data['data']['results'] is List) {
          final apiResults = data['data']['results'] as List;
          for (var item in apiResults) {
            final song = _parseSongItem(item);
            if (song != null) {
              moreResults.add(song);
            }
          }
          _searchResults.addAll(moreResults);
        }
      } // No error message here to allow silent additions
    } catch (e) {
      print("Fetch more error: $e"); // Log silently
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults.clear();
    _currentQuery = '';
    _errorMessage = null;
    notifyListeners();
  }

  Song? _parseSongItem(Map<String, dynamic> item) {
    try {
      String? downloadUrl;
      if (item['download_url'] is List && (item['download_url'] as List).isNotEmpty) {
        final lastUrl = (item['download_url'] as List).last;
        if (lastUrl is Map && lastUrl.containsKey('link')) {
          downloadUrl = lastUrl['link'];
        }
      }
      if (downloadUrl == null) return null;

      String imageUrl = '';
      if (item['image'] is List && (item['image'] as List).isNotEmpty) {
        final lastImage = (item['image'] as List).last;
        if (lastImage is Map && lastImage.containsKey('link')) {
          imageUrl = lastImage['link'];
        }
      }

      String artist = 'Unknown Artist';
      if (item.containsKey('primary_artists') && item['primary_artists'] is List && (item['primary_artists'] as List).isNotEmpty) {
         artist = (item['primary_artists'] as List).map((artistObj) => artistObj['name'] as String? ?? '').join(', ');
      } else if (item.containsKey('artist') && item['artist'] is String) {
        artist = item['artist']; // For trending songs which have a different structure
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
        title: item['name'] as String? ?? item['title'] as String? ?? 'Unknown Title', // title for trending
        artist: artist,
        thumbUrl: imageUrl,
        type: 'saavn',
        duration: duration,
      );
    } catch (e) {
      print("Error parsing individual song item: $e");
      return null;
    }
  }
}
