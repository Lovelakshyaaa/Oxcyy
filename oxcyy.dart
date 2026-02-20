import 'dart:convert';
import 'package:http/http.dart' as http;

class OxcyApiService {
  // Your deployed Vercel backend base URL
  static const String baseUrl = 'https://musik-olive.vercel.app/api';

  /// Centralized response handler to prevent repetitive code and crashes.
  /// The backend typically wraps results in a { "success": true/false, "data": ... } format.
  static dynamic _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      final decodedData = json.decode(response.body);
      
      if (decodedData['success'] == true) {
        return decodedData['data'];
      } else {
        throw Exception(decodedData['message'] ?? 'API returned an unknown error');
      }
    } else {
      throw Exception('Failed to load data. Status Code: ${response.statusCode}');
    }
  }

  // ==========================================
  // 1. SEARCH ENDPOINTS
  // ==========================================

  /// Global Search (Searches across songs, albums, playlists, and artists)
  static Future<dynamic> searchAll(String query) async {
    final uri = Uri.parse('$baseUrl/search/all?query=$query');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - searchAll Error: $e');
      return null;
    }
  }

  /// Search Specifically for Songs
  static Future<dynamic> searchSongs(String query, {int page = 1, int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/search/songs?query=$query&page=$page&limit=$limit');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - searchSongs Error: $e');
      return null;
    }
  }

  /// Search Albums
  static Future<dynamic> searchAlbums(String query, {int page = 1, int limit = 10}) async {
    final uri = Uri.parse('$baseUrl/search/albums?query=$query&page=$page&limit=$limit');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - searchAlbums Error: $e');
      return null;
    }
  }

  // ==========================================
  // 2. FETCH DETAILS BY ID ENDPOINTS
  // ==========================================

  /// Get Specific Song Details by ID
  static Future<dynamic> getSongById(String songId) async {
    final uri = Uri.parse('$baseUrl/songs/$songId');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getSongById Error: $e');
      return null;
    }
  }

  /// Get Specific Album Details by ID
  static Future<dynamic> getAlbumById(String albumId) async {
    final uri = Uri.parse('$baseUrl/albums/$albumId');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getAlbumById Error: $e');
      return null;
    }
  }

  /// Get Specific Playlist Details by ID
  static Future<dynamic> getPlaylistById(String playlistId) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getPlaylistById Error: $e');
      return null;
    }
  }

  /// Get Artist Details and Top Songs by Artist ID
  static Future<dynamic> getArtistById(String artistId) async {
    final uri = Uri.parse('$baseUrl/artists/$artistId');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getArtistById Error: $e');
      return null;
    }
  }

  // ==========================================
  // 3. RECOMMENDATIONS & SUGGESTIONS
  // ==========================================

  /// Get Song Suggestions (Autoplay recommendations based on a current song ID)
  static Future<dynamic> getSongSuggestions(String songId) async {
    final uri = Uri.parse('$baseUrl/songs/$songId/suggestions');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getSongSuggestions Error: $e');
      return null;
    }
  }
}