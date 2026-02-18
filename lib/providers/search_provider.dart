import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/utils/clients.dart'; // Import the custom client

class SearchProvider with ChangeNotifier {
  final CustomHttpClient _client = CustomHttpClient();

  List<dynamic> _popularResults = [];
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

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _fetchAndParse(String url, Function(Map<String, dynamic>) parser) async {
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        parser(data);
      } else {
        _errorMessage = "API Error: Failed to fetch data (Code: ${response.statusCode})";
      }
    } catch (e) {
      _errorMessage = "Network Error: Could not connect to service.";
      print("Network request error: $e");
    }
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

    await _fetchAndParse('https://saavn.me/modules?language=hindi,english', (data) {
      final List<dynamic> results = [];
      if (data['trending'] != null && data['trending']['albums'] is List) {
        results.addAll((data['trending']['albums'] as List).map((item) => _parseSongItem(item)).whereType<Song>());
      }
      if (data['artists'] != null && data['artists'] is List) {
        results.addAll((data['artists'] as List).map((item) => _parseArtistItem(item)).whereType<Artist>());
      }
      _popularResults = results;
    });

    _isFetchingPopular = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty || _isSearching) return;

    _currentQuery = query;
    _currentPage = 1;
    _isSearching = true;
    _clearAllResults();
    notifyListeners();

    await _fetchAndParse('https://saavn.me/search/all?query=${Uri.encodeComponent(query)}', _parseAllResults);

    _isSearching = false;
    notifyListeners();
  }

  void _parseAllResults(Map<String, dynamic> data) {
    if (data['topQuery'] != null && data['topQuery']['results'] is List) {
      final topQueryResults = data['topQuery']['results'] as List;
      if (topQueryResults.isNotEmpty) {
        _topResult = _parseTopQueryResult(topQueryResults.first);
      }
    }
    if (data['songs'] != null && data['songs']['results'] is List) {
      _songResults = (data['songs']['results'] as List).map((item) => _parseSongItem(item)).whereType<Song>().toList();
    }
    if (data['artists'] != null && data['artists']['results'] is List) {
      _artistResults = (data['artists']['results'] as List).map((item) => _parseArtistItem(item)).whereType<Artist>().toList();
    }
  }

  TopQueryResult? _parseTopQueryResult(Map<String, dynamic> item) {
    final type = item['type'];
    if (type == 'artist') return _parseArtistItem(item);
    if (type == 'song') return _parseSongItem(item);
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
        final Map? lastUrl = (item['downloadUrl'] as List).lastWhere((u) => u['quality'] == '320kbps', orElse: () => (item['downloadUrl'] as List).last);
        if (lastUrl != null && lastUrl.containsKey('link')) {
          downloadUrl = lastUrl['link'];
        }
      }
      if (downloadUrl == null) return null;

      return Song(
        id: downloadUrl,
        title: item['name'] as String? ?? item['title'] as String? ?? 'Unknown Title',
        artist: _getArtistName(item),
        thumbUrl: _getImageUrl(item['image']),
        type: 'saavn',
        duration: _getDuration(item['duration']),
      );
    } catch (e) {
      print("Error parsing song item: $e");
      return null;
    }
  }
  
  String _getArtistName(Map<String, dynamic> item) {
    if (item['primaryArtists'] is String && (item['primaryArtists'] as String).isNotEmpty) return item['primaryArtists'];
    if (item['primaryArtists'] is List && (item['primaryArtists'] as List).isNotEmpty) return (item['primaryArtists'] as List).map((a) => a['name']).join(', ');
    if (item['artists'] is List && (item['artists'] as List).isNotEmpty) return (item['artists'] as List).map((a) => a['name']).join(', ');
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

    await _fetchAndParse('https://saavn.me/search/songs?query=${Uri.encodeComponent(_currentQuery)}&page=$_currentPage', (data) {
      if (data['results'] is List) {
        _songResults.addAll((data['results'] as List).map((item) => _parseSongItem(item)).whereType<Song>());
      }
    });

    _isFetchingMore = false;
    notifyListeners();
  }

  void clearSearch() {
    _clearAllResults();
    notifyListeners();
  }
}
