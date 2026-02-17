import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:oxcy/services/decipher_service.dart';

// A custom AudioSource that gets a playable URL for any YouTube video,
// handling deciphering if necessary.
class YoutubeAudioSource extends UriAudioSource {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final DecipherService _decipherService = DecipherService();

  // Private constructor
  YoutubeAudioSource._(Uri uri, {required dynamic tag}) : super(uri, tag: tag);

  // Static factory method to create an instance
  static Future<YoutubeAudioSource> create(String videoId, {required dynamic tag}) async {
    // Ensure the decipher service is ready.
    await _decipherService.init();

    // Get the stream manifest.
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    
    // Get the audio stream info.
    final streamInfo = manifest.audioOnly.withHighestBitrate();
    final originalUrl = streamInfo.url;

    Uri finalUrl;

    // Check if the URL contains the ciphered signature parameter 's'.
    if (originalUrl.queryParameters.containsKey('s')) {
      // This is the protected signature from YouTube.
      final String cipheredSignature = originalUrl.queryParameters['s']!;
      
      // This is the playable signature we get from our JS solver.
      final String solvedSignature = await _decipherService.decipher(cipheredSignature);

      // Create new query parameters with the solved signature ('n' parameter).
      final newQueryParameters = Map<String, String>.from(originalUrl.queryParameters)
        ..remove('s')
        ..addAll({'n': solvedSignature});

      // Reconstruct the URL.
      finalUrl = originalUrl.replace(queryParameters: newQueryParameters);
    } else {
      // The URL is not ciphered, use it directly.
      finalUrl = originalUrl;
    }

    return YoutubeAudioSource._(finalUrl, tag: tag);
  }

  // It's good practice to provide a way to close the services.
  static void dispose() {
    _yt.close();
    _decipherService.dispose();
  }
}
