import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Converts a Video ID (e.g., 'dQw4w9WgXcQ') into a direct MP3/M4A URL
  Future<String?> getStreamUrl(String videoId) async {
    try {
      // 1. Get the manifest (the list of all available streams)
      var manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // 2. Filter: Get the best quality audio-only stream (m4a usually)
      var audioStream = manifest.audioOnly.withHighestBitrate();

      // 3. Return the actual URL that JustAudio can play
      return audioStream.url.toString();
    } catch (e) {
      print("❌ Error extracting stream: $e");
      return null;
    }
  }

  /// Call this when closing the app to prevent memory leaks
  void dispose() {
    _yt.close();
  }
}
