import 'dart:convert';
import 'package:http/http.dart' as http;

// Service class to interact with the JioSaavn API wrapper.
class OxcyApiService {
  // The base URL for the API.
  static const String baseUrl = 'https://musik-olive.vercel.app/api/';

  /// Processes the HTTP response, parsing the JSON and handling potential errors.
  static dynamic _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      final decodedData = json.decode(response.body);
      if (decodedData is Map &&
          decodedData.containsKey('success') &&
          decodedData['success'] == true) {
        // On success, return the actual data payload.
        return decodedData['data'];
      }
      return decodedData;
    } else {
      throw Exception(
        'Failed to load data. Status Code: ${response.statusCode}',
      );
    }
  }

  /// Fetches the main modules for the explore screen (trending, charts, etc.).
  static Future<dynamic> getHomeData() async {
    final uri = Uri.parse('${baseUrl}modules');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getHomeData Error: $e');
      return null;
    }
  }

  /// Searches for songs, albums, and artists based on a query.
  static Future<dynamic> searchAll(String query) async {
    // FIXED: Added the /all to the endpoint
    final uri = Uri.parse(
      '${baseUrl}search/all?query=${Uri.encodeComponent(query)}',
    );
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - searchAll Error: $e');
      return null;
    }
  }

  /// Fetches detailed information for a specific song by its ID.
  static Future<dynamic> getSongById(String songId) async {
    // FIXED: Changed to path parameter instead of query parameter
    final uri = Uri.parse('${baseUrl}songs/$songId');
    try {
      final response = await http.get(uri);
      final data = _processResponse(response);
      return (data is List && data.isNotEmpty) ? data[0] : data;
    } catch (e) {
      print('OxcyApiService - getSongById Error: $e');
      return null;
    }
  }

  /// Fetches detailed information for a specific album by its ID.
  static Future<dynamic> getAlbumById(String albumId) async {
    // FIXED: Changed to path parameter
    final uri = Uri.parse('${baseUrl}albums/$albumId');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getAlbumById Error: $e');
      return null;
    }
  }

  /// Fetches detailed information for a specific playlist by its ID.
  static Future<dynamic> getPlaylistById(String playlistId) async {
    // FIXED: Changed to path parameter
    final uri = Uri.parse('${baseUrl}playlists/$playlistId');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getPlaylistById Error: $e');
      return null;
    }
  }

  /// Fetches detailed information for a specific artist by their ID.
  static Future<dynamic> getArtistById(String artistId) async {
    // FIXED: Changed to path parameter
    final uri = Uri.parse('${baseUrl}artists/$artistId');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getArtistById Error: $e');
      return null;
    }
  }

  /// Fetches song suggestions for a given song ID, for autoplay purposes.
  static Future<dynamic> getSongSuggestions(String songId) async {
    // Firebase actually got this one perfectly correct!
    final uri = Uri.parse('${baseUrl}songs/$songId/suggestions');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getSongSuggestions Error: $e');
      return null;
    }
  }
}
