import 'dart:async';
import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/services/oxcy_api_service.dart';

// Manages the application's music data, state, and interactions with the API.
class MusicData with ChangeNotifier {
  // --- STATE PROPERTIES ---
  bool _isLoading = true; // For initial launch data loading.
  bool get isLoading => _isLoading;

  bool _isSearching = false; // For search-specific loading states.
  bool get isSearching => _isSearching;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Holds the data for the main "explore" screen, categorized by module.
  Map<String, List<SearchResult>> _modules = {};
  Map<String, List<SearchResult>> get modules => _modules;

  // Holds the results of a user's search.
  List<SearchResult> _searchResults = [];
  List<SearchResult> get searchResults => _searchResults;

  // --- INITIALIZATION ---
  MusicData() {
    // Fetch the initial data required to populate the UI when the app starts.
    fetchLaunchData();
  }

  // --- DATA FETCHING METHODS ---

  /// Fetches the initial data for the home screen from the `/modules` endpoint.
  Future<void> fetchLaunchData() async {
    _setLoading(true);
    try {
      final response = await OxcyApiService.getHomeData();
      if (response != null && response['data'] != null) {
        final data = response['data'];
        _modules.clear(); // Clear previous data.

        // Safely parse and build each module from the API response.
        _modules['albums'] = _buildList(data['albums'], Album.fromJson);
        _modules['charts'] = _buildList(data['charts'], Chart.fromJson);
        _modules['playlists'] = _buildList(data['playlists'], Playlist.fromJson);
        
        // Trending data is nested, so handle it separately.
        if (data['trending'] != null) {
            _modules['trending_songs'] = _buildList(data['trending']['songs'], Song.fromJson);
            _modules['trending_albums'] = _buildList(data['trending']['albums'], Album.fromJson);
        }

      } else {
        _setError('Failed to load essential app data.');
      }
    } catch (e) {
      _setError('A network error occurred. Please check your connection.');
      print("fetchLaunchData Error: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// Searches for all types of content (songs, albums, artists, playlists).
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      clearSearch();
      return;
    }
    _setSearching(true);
    try {
      final response = await OxcyApiService.searchAll(query);
      if (response != null) {
        _searchResults.clear();

        // The /search/all endpoint returns a map of result categories.
        response.forEach((category, results) {
          if (results is Map && results.containsKey('results')) {
            final items = results['results'] as List<dynamic>? ?? [];
            for (var item in items) {
               final result = _parseItem(item as Map<String, dynamic>);
               if (result != null) {
                 _searchResults.add(result);
               }
            }
          }
        });

      } else {
        _setError('Search failed. No results found.');
      }
    } catch (e) {
      _setError('A network error occurred during the search.');
       print("Search Error: $e");
    } finally {
      _setSearching(false);
    }
  }

  /// Clears the current search results and notifies listeners.
  void clearSearch() {
    _searchResults.clear();
    notifyListeners();
  }
  
  // --- UTILITY & HELPER METHODS ---

  /// Generic helper to build a list of objects from a JSON list using a factory.
  List<T> _buildList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data == null || data is! List) return [];
    return data
        .map((item) => fromJson(item as Map<String, dynamic>))
        .where((item) => (item as SearchResult).id.isNotEmpty) // Filter out invalid items
        .toList();
  }
  
  /// Parses a single JSON item into the correct SearchResult model based on its type.
  SearchResult? _parseItem(Map<String, dynamic> item) {
    final type = item['type']?.toString().toLowerCase();
    switch (type) {
      case 'song':
        return Song.fromJson(item);
      case 'album':
        return Album.fromJson(item);
      case 'artist':
        return Artist.fromJson(item);
      case 'playlist':
        return Playlist.fromJson(item);
      default:
        return null; // Ignore unknown types.
    }
  }

  /// Helper to set the main loading state and notify listeners.
  void _setLoading(bool isLoading) {
    _isLoading = isLoading;
    _errorMessage = null;
    notifyListeners();
  }

  /// Helper to set the search loading state and notify listeners.
  void _setSearching(bool isSearching) {
    _isSearching = isSearching;
    _errorMessage = null;
    notifyListeners();
  }

  /// Helper to set an error message and notify listeners.
  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }
}
