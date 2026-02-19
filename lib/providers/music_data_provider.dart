import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:oxcy/models/search_models.dart';

class MusicData with ChangeNotifier {
  final String _baseUrl = "https://music-three-woad.vercel.app";

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, List<dynamic>> _modules = {};
  Map<String, List<dynamic>> get modules => _modules;

  bool _isSearching = false;
  bool get isSearching => _isSearching;
  List<dynamic> _searchResults = [];
  List<dynamic> get searchResults => _searchResults;

  MusicData() {
    fetchLaunchData();
  }

  // --- SAFE PARSING HELPERS ---
  String _getId(Map<String, dynamic> item) => item['id']?.toString() ?? item['songid']?.toString() ?? '';
  String _getTitle(Map<String, dynamic> item) => item['name']?.toString() ?? item['title']?.toString() ?? 'Unknown';

  String _getSubtitle(Map<String, dynamic> item) {
    final subtitle = item['subtitle']?.toString();
    if (subtitle != null && subtitle.isNotEmpty) return subtitle;
    final artist = _getArtistName(item);
    if (artist.isNotEmpty && artist != 'Unknown Artist') return artist;
    final year = item['year']?.toString();
    if (year != null && year.isNotEmpty) return year;
    return item['type']?.toString() ?? '';
  }

  String _getArtistName(Map<String, dynamic> item) {
    dynamic artists = item['primaryArtists'] ?? item['artists'];
    if (artists is String && artists.isNotEmpty) return artists;
    if (artists is List && artists.isNotEmpty) {
      return artists.map((a) => a['name']?.toString() ?? '').where((s) => s.isNotEmpty).join(', ');
    }
    return item['subtitle']?.toString() ?? 'Unknown Artist';
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
    if (imageField is String && imageField.isNotEmpty) return imageField;
    if (imageField is List && imageField.isNotEmpty) {
      final lastImage = imageField.last;
      if (lastImage is Map && lastImage['link'] != null) {
        return lastImage['link'];
      }
    }
    return 'https://via.placeholder.com/150'; // Return a placeholder
  }

  String? _getDownloadUrl(dynamic urlField) {
    if (urlField is List && urlField.isNotEmpty) {
      final lastUrl = urlField.last;
      if (lastUrl is Map && lastUrl['link'] != null) {
        return lastUrl['link'];
      }
    }
    if (urlField is String && urlField.isNotEmpty) return urlField;
    return null;
  }

  // --- END HELPERS ---

  Future<void> fetchLaunchData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$_baseUrl/modules?lang=english'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        _modules.clear();

        _modules['trending_songs'] = (data['trending']?['data'] as List? ?? []).map((item) => buildSong(item)).whereType<Song>().toList();
        _modules['playlists'] = (data['playlists']?['data'] as List? ?? []).map((item) => buildPlaylist(item)).whereType<Playlist>().toList();
        _modules['charts'] = (data['charts']?['data'] as List? ?? []).map((item) => buildChart(item)).whereType<Chart>().toList();
        _modules['albums'] = (data['albums']?['data'] as List? ?? []).map((item) => buildAlbum(item)).whereType<Album>().toList();

      } else {
        _errorMessage = "Failed to load essential app data.";
      }
    } catch (e) {
      _errorMessage = "A network error occurred. Check your connection.";
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

        final allResults = [
          ...(data['topQuery']?['results'] as List? ?? []),
          ...(data['songs']?['results'] as List? ?? []),
          ...(data['albums']?['results'] as List? ?? []),
          ...(data['artists']?['results'] as List? ?? []),
          ...(data['playlists']?['results'] as List? ?? []),
        ];

        _searchResults = allResults.map((item) => _parseSearchResultItem(item)).where((item) => item != null).toList();
      } else {
        _errorMessage = "Search failed.";
      }
    } catch (e) {
      _errorMessage = "A network error occurred during search.";
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  dynamic _parseSearchResultItem(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    switch (type) {
      case 'song': return buildSong(item);
      case 'artist': return buildArtist(item);
      case 'album': return buildAlbum(item);
      case 'playlist': return buildPlaylist(item);
      default: return null;
    }
  }

  Song? buildSong(Map<String, dynamic> item) {
    final id = _getId(item);
    if (id.isEmpty) return null;
    return Song(
      id: id,
      title: _getTitle(item),
      artist: _getArtistName(item),
      thumbUrl: _getImageUrl(item['image']),
      type: item['type']?.toString() ?? 'song',
      duration: _getDuration(item['duration']),
      downloadUrl: _getDownloadUrl(item['downloadUrl']),
    );
  }

  Artist? buildArtist(Map<String, dynamic> item) {
    final id = _getId(item);
    if (id.isEmpty) return null;
    return Artist(id: id, name: _getTitle(item), imageUrl: _getImageUrl(item['image']));
  }

  Album? buildAlbum(Map<String, dynamic> item) {
    final id = _getId(item);
    if (id.isEmpty) return null;
    return Album(id: id, title: _getTitle(item), imageUrl: _getImageUrl(item['image']), subtitle: _getSubtitle(item));
  }

  Playlist? buildPlaylist(Map<String, dynamic> item) {
    final id = _getId(item);
    if (id.isEmpty) return null;
    return Playlist(id: id, title: _getTitle(item), imageUrl: _getImageUrl(item['image']), subtitle: _getSubtitle(item));
  }

  Chart? buildChart(Map<String, dynamic> item) {
    final id = _getId(item);
    if (id.isEmpty) return null;
    return Chart(id: id, title: _getTitle(item), imageUrl: _getImageUrl(item['image']));
  }
}
