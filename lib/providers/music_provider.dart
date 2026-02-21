
import 'dart:async';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/services/oxcy_api_service.dart';

// Helper to convert MediaItem to a consistent Song object
Song _songFromMediaItem(MediaItem mediaItem) {
  if (mediaItem.extras != null && mediaItem.extras!['song'] is Map<String, dynamic>) {
    try {
      return Song.fromJson(mediaItem.extras!['song']);
    } catch (e) {
      // Fallback for safety
    }
  }

  // Fallback: construct from MediaItem properties if 'song' extra is missing or malformed
  return Song(
    id: mediaItem.id,
    name: mediaItem.title,
    type: 'song',
    image: mediaItem.artUri != null ? [Link(quality: '500x500', url: mediaItem.artUri.toString())] : [],
    artists: mediaItem.artist != null ? [Artist(id: '', name: mediaItem.artist!, type: 'artist', image: [])] : [],
    duration: mediaItem.duration?.inSeconds,
    downloadUrl: mediaItem.extras?['url'] != null ? [Link(quality: '320kbps', url: mediaItem.extras!['url'])] : [],
  );
}


class MusicProvider with ChangeNotifier {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioHandler _audioHandler;

  Song? _currentSong;

  bool _isPlayerVisible = false;
  String? _errorMessage;
  String? _loadingSongId;

  bool _isFetchingLocal = false;
  List<AlbumModel> _localAlbums = [];

  Song? get currentSong => _currentSong;
  bool get isPlayerVisible => _isPlayerVisible;
  String? get errorMessage => _errorMessage;
  String? get loadingSongId => _loadingSongId;
  bool get isFetchingLocal => _isFetchingLocal;
  List<AlbumModel> get localAlbums => _localAlbums;
  
  // Expose the playback state stream for widgets that need to react to multiple state changes
  Stream<PlaybackState> get playbackState => _audioHandler.playbackState;
  Stream<MediaItem?> get mediaItem => _audioHandler.mediaItem;
  
  // Provide a simple getter for the current playing state
  bool get isPlaying => _audioHandler.playbackState.value.playing;


  MusicProvider(this._audioHandler) {
    _listenToPlaybackState();
  }

  void _listenToPlaybackState() {
    // Listen for changes in the playback state (playing, paused, buffering, etc.)
    _audioHandler.playbackState.listen((playbackState) {
      final processingState = playbackState.processingState;
      if (processingState == AudioProcessingState.loading ||
          processingState == AudioProcessingState.buffering) {
        // Set loading indicator for the specific song
        _loadingSongId = _audioHandler.mediaItem.value?.id;
      } else {
        _loadingSongId = null;
      }
      notifyListeners();
    });

    // Listen for changes in the currently playing media item
    _audioHandler.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        _currentSong = _songFromMediaItem(mediaItem);
      }
      notifyListeners();
    });
  }
  
  Future<Map<String, List<SearchResult>>> search(String query) async {
    return await OxcyApiService.searchAll(query);
  }

  /// Sets the audio handler's queue and starts playing from a specific index.
  /// This is the primary method for starting playback of a list of songs (album, playlist, etc.).
  Future<void> setPlaylist(List<dynamic> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return;

    final mediaItems = songs.map((song) {
      if (song is Song) { // Online song
        return MediaItem(
          id: song.id.toString(),
          title: song.name,
          artist: song.artistNames,
          artUri: Uri.parse(song.highQualityImageUrl),
          duration: Duration(seconds: song.duration ?? 0),
          extras: {
            'url': song.highQualityStreamUrl,
            'song': song.toJson(),
          },
        );
      } else if (song is SongModel) { // Local song
        return MediaItem(
          id: song.id.toString(),
          title: song.title,
          artist: song.artist ?? 'Unknown Artist',
          duration: Duration(milliseconds: song.duration ?? 0),
          extras: {
            'url': song.uri, // This is the local file path
            // Create a consistent 'song' map for local files as well
            'song': {
              'id': song.id.toString(),
              'name': song.title,
              'type': 'song',
              'image': [],
              'duration': (song.duration ?? 0) ~/ 1000, // to seconds
              'artists': [{'id': '', 'name': song.artist ?? 'Unknown Artist', 'type': 'artist', 'image': []}],
              'downloadUrl': [{'quality': 'local', 'url': song.uri}],
            },
          },
        );
      }
      return null;
    }).whereType<MediaItem>().toList();

    if (mediaItems.isNotEmpty) {
      await _audioHandler.updateQueue(mediaItems);
      await _audioHandler.skipToQueueItem(initialIndex);
      await _audioHandler.play();
      showPlayer(); // Make the full player visible when a new playlist starts
    }
  }

  /// A convenience method to play a single song.
  Future<void> play(dynamic song) async {
    await setPlaylist([song]);
  }

  // --- Playback Controls ---
  void resume() => _audioHandler.play();
  void pause() => _audioHandler.pause();
  void seek(Duration position) => _audioHandler.seek(position);
  Future<void> playNext() => _audioHandler.skipToNext();
  Future<void> playPrevious() => _audioHandler.skipToPrevious();

  // --- UI Control ---
  void showPlayer() {
    if (!_isPlayerVisible) {
      _isPlayerVisible = true;
      notifyListeners();
    }
  }

  void hidePlayer() {
    if (_isPlayerVisible) {
      _isPlayerVisible = false;
      notifyListeners();
    }
  }

  void _setError(String message) {
    _errorMessage = message;
    _loadingSongId = null;
    notifyListeners();
  }

  // --- Local Music Fetching ---
  Future<void> fetchLocalMusic() async {
    _isFetchingLocal = true;
    notifyListeners();
    try {
      // Ensure we have permissions before querying
      if (await _audioQuery.permissionsStatus()) {
        _localAlbums = await _audioQuery.queryAlbums(
          sortType: AlbumSortType.ALBUM,
          orderType: OrderType.ASC_OR_SMALLER,
          ignoreCase: true,
        );
      } else {
        await _audioQuery.permissionsRequest();
        // Retry fetching if permissions are granted
        if (await _audioQuery.permissionsStatus()) {
          _localAlbums = await _audioQuery.queryAlbums();
        } else {
           _setError("Storage permission not granted.");
        }
      }
    } catch (e) {
      _setError("Failed to fetch local albums: $e");
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  /// Correctly fetches songs for a specific local album.
  Future<List<SongModel>> getLocalSongsByAlbum(int albumId) async {
    // This is the correct method to query songs from a specific album ID.
    // The sortType parameter is removed as it's no longer valid and the
    // default sort order is by track number.
    return await _audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      albumId,
    );
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) {
    return _audioQuery.queryArtwork(id, type, size: 200); // specify size for better performance
  }
}
