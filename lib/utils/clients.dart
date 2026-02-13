import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A client that adds custom headers to every request.
class _HeaderAddingClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  _HeaderAddingClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

/// Creates a YoutubeHttpClient that mimics an Oculus Quest 3 (Android VR)
YoutubeHttpClient createAndroidVrClient() {
  final inner = IOClient(
    HttpClient()
      ..userAgent = 'com.google.android.youtube/20.10.38 (Linux; U; Android 12L) gzip'
      ..connectionTimeout = const Duration(seconds: 30),
  );

  final clientWithHeaders = _HeaderAddingClient(inner, {
    'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 12L) gzip',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'X-YouTube-Client-Name': '28',   // ANDROID_VR
    'X-YouTube-Client-Version': '1.65.10',
  });

  return YoutubeHttpClient(clientWithHeaders);
}

/// Fallback Android client
YoutubeHttpClient createAndroidClient() {
  final inner = IOClient(
    HttpClient()
      ..userAgent = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
  );

  final clientWithHeaders = _HeaderAddingClient(inner, {
    'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
    'X-YouTube-Client-Name': '3',    // ANDROID
    'X-YouTube-Client-Version': '20.10.38',
  });

  return YoutubeHttpClient(clientWithHeaders);
}
