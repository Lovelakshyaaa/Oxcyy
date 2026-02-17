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
    
    // Use the general StreamInfo class to access the necessary properties.
    StreamInfo streamInfo = manifest.audioOnly.withHighestBitrate();

    Uri streamUri;
    if (streamInfo.isCiphered) {
      // The stream is protected, we need to decipher the signature.
      final decipheredSignature = await _decipherService.decipher(streamInfo.signature);
      streamUri = streamInfo.url.replace(queryParameters: {'n': decipheredSignature});
    } else {
      // The stream is not protected, we can use the URL directly.
      streamUri = streamInfo.url;
    }

    return YoutubeAudioSource._(streamUri, tag: tag);
  }

  // It's good practice to provide a way to close the services.
  static void dispose() {
    _yt.close();
    _decipherService.dispose();
  }
}
