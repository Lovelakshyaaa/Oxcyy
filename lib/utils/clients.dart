import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';

/// Creates a YoutubeHttpClient that mimics an Oculus Quest 3 (Android VR)
YoutubeHttpClient createAndroidVrClient() {
  final client = YoutubeHttpClient(
    client: IOClient(
      HttpClient()
        ..userAgent = 'com.google.android.youtube/20.10.38 (Linux; U; Android 12L) gzip'
        ..connectionTimeout = const Duration(seconds: 30),
    ),
  );
  client.defaultHeaders.addAll({
    'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 12L) gzip',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'X-YouTube-Client-Name': '28',   // ANDROID_VR
    'X-YouTube-Client-Version': '1.65.10',
  });
  return client;
}

/// Fallback Android client
YoutubeHttpClient createAndroidClient() {
  final client = YoutubeHttpClient();
  client.defaultHeaders.addAll({
    'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
    'X-YouTube-Client-Name': '3',    // ANDROID
    'X-YouTube-Client-Version': '20.10.38',
  });
  return client;
}
