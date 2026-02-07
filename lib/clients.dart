import 'package:youtube_explode_dart/youtube_explode_dart.dart';

// Credit: Based on Musify/yt-dlp implementation
// These "Fake Clients" trick YouTube into giving us working streams.

// The "Golden Key" - Mimics an Oculus Quest 3 to get high-quality M4A streams
const customAndroidVr = YoutubeApiClient({
  'context': {
    'client': {
      'clientName': 'ANDROID_VR',
      'clientVersion': '1.65.10',
      'deviceModel': 'Quest 3',
      'osVersion': '12L',
      'osName': 'Android',
      'androidSdkVersion': '32',
      'hl': 'en',
      'timeZone': 'UTC',
      'utcOffsetMinutes': 0,
    },
    'contextClientName': 28,
    'requireJsPlayer': false,
  },
}, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

// Backup Client - Mimics an older Android phone (use only if VR fails)
const customAndroidSdkless = YoutubeApiClient({
  'context': {
    'client': {
      'clientName': 'ANDROID',
      'clientVersion': '20.10.38',
      'userAgent':
          'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip',
      'osName': 'Android',
      'osVersion': '11',
    },
  },
  'contextClientName': 3,
  'requireJsPlayer': false,
}, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
