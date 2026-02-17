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
    
    // Choose the best audio-only stream.
    var streamInfo = manifest.audioOnly.withHighestBitrate();

    Uri streamUri;
    if (streamInfo.isCiphered) {
      // The stream is protected, we need to decipher the signature.
      final decipheredSignature = await _decipherService.decipher(streamInfo.signature);
      streamUri = streamInfo.uri.replace(queryParameters: {'n': decipheredSignature});
    } else {
      // The stream is not protected, we can use the URL directly.
      streamUri = streamInfo.uri;
    }

    return YoutubeAudioSource._(streamUri, tag: tag);
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // The UriAudioSource will handle the streaming from the resolved URL.
    return super.request(start, end);
  }

  // It's good practice to provide a way to close the services.
  static void dispose() {
    _yt.close();
    _decipherService.dispose();
  }
}
