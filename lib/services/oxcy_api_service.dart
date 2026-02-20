import 'dart:convert';
import 'package:http/http.dart' as http;

// Service class to interact with the JioSaavn API.
class OxcyApiService {
  // The base URL for the JioSaavn API.
  static const String baseUrl = 'https://musik-olive.vercel.app/api';

  /// Processes the HTTP response, parsing the JSON and handling potential errors.
  /// The API wraps successful responses in a {"success": true, "data": ...} structure.
  static dynamic _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      final decodedData = json.decode(response.body);
      if (decodedData is Map &&
          decodedData.containsKey('success') &&
          decodedData['success'] == true) {
        // On success, return the actual data payload.
        return decodedData['data'];
      }
      // Return the decoded data if the structure is unexpected but the call was successful.
      return decodedData;
    } else {
      // Throw an exception if the server returned an error code.
      throw Exception('Failed to load data. Status Code: ${response.statusCode}');
    }
  }

  /// Fetches the main modules for the explore screen (e.g., trending, charts, playlists).
  static Future<dynamic> getHomeData() async {
    final uri = Uri.parse('$baseUrl/modules');
    try {
      final response = await http.get(uri);
      return _processResponse(response);
    } catch (e) {
      print('OxcyApiService - getHomeData Error: $e');
      return null; // Return null on error to be handled by the provider.
    }
  }

  /// Searches for songs, albums, and artists based on a query.
  static Future<dynamic> searchAll(String query) async {
    // Uses the /search/all endpoint for a global search.
    final uri = Uri.parse('$baseUrl/search/all?query=$query');
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
    // Uses the /songs endpoint with an 'id' query parameter.
    final uri = Uri.parse('$baseUrl/songs?id=$songId');
    try {
      final response = await http.get(uri);
      // The response for a single song is often a list, so we take the first element.
      final data = _processResponse(response);
      return (data is List && data.isNotEmpty) ? data[0] : data;
    } catch (e) {
      print('OxcyApiService - getSongById Error: $e');
      return null;
    }
  }

  /// Fetches detailed information for a specific album by its ID.
  static Future<dynamic> getAlbumById(String albumId) async {
    final uri = Uri.parse('$baseUrl/albums?id=$albumId');
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
    final uri = Uri.parse('$baseUrl/playlists?id=$playlistId');
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
    final uri = Uri.parse('$baseUrl/artists?id=$artistId');
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
