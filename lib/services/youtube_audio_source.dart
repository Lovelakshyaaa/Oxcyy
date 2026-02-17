import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:oxcy/services/decipher_service.dart';

// A custom AudioSource that provides a raw byte stream for any YouTube video.
// It uses pre-fetched stream metadata to correctly report stream length,
// ensuring reliable playback and seeking.
class YoutubeAudioSource extends StreamAudioSource {
  static final YoutubeExplode _yt = YoutubeExplode();
  static final DecipherService _decipherService = DecipherService();
  
  final Uri _streamUrl;
  final int _sourceLength;

  // Private constructor that stores the URL and the exact source length.
  YoutubeAudioSource._(this._streamUrl, this._sourceLength, {required dynamic tag}) : super(tag: tag);

  // Static factory method to create an instance.
  static Future<YoutubeAudioSource> create(String videoId, {required dynamic tag}) async {
    await _decipherService.init();

    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final streamInfo = manifest.audioOnly.withHighestBitrate();
    final originalUrl = streamInfo.url;

    // *** THE CRITICAL FIX ***
    // Get the exact stream size directly from the stream metadata.
    final int totalSize = streamInfo.size.totalBytes;

    Uri finalUrl;

    if (originalUrl.queryParameters.containsKey('s')) {
      final cipheredSignature = originalUrl.queryParameters['s']!;
      final solvedSignature = await _decipherService.decipher(cipheredSignature);

      final newQueryParameters = Map<String, String>.from(originalUrl.queryParameters)
        ..remove('s')
        ..addAll({'n': solvedSignature});

      finalUrl = originalUrl.replace(queryParameters: newQueryParameters);
    } else {
      finalUrl = originalUrl;
    }

    return YoutubeAudioSource._(finalUrl, totalSize, tag: tag);
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final client = http.Client();
    final request = http.Request('GET', _streamUrl);

    request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.88 Safari/537.36';

    if (start != null || end != null) {
      request.headers['Range'] = 'bytes=${start ?? ''}-${end ?? ''}';
    }

    final response = await client.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("HTTP request failed with status: ${response.statusCode}");
    }

    return StreamAudioResponse(
      sourceLength: _sourceLength, // Use the accurate, pre-fetched total size.
      contentLength: response.contentLength, // The size of the current chunk.
      offset: start ?? 0,
      stream: response.stream,
      contentType: response.headers['content-type'] ?? 'audio/mpeg',
    );
  }

  static void dispose() {
    _yt.close();
    _decipherService.dispose();
  }
}
