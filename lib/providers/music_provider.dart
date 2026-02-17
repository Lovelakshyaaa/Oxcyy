import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/services/audio_handler.dart';

// Represents a single song, abstracting over local and YouTube sources.
class Song {
  final String id; // videoId for YouTube, file URI for local
  final String title;
  final String artist;
  final String thumbUrl;
  final String type;
  final int? localId;
  final int? albumId;
  final Duration? duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbUrl,
    required this.type,
    this.localId,
    this.albumId,
    this.duration,
  });
}

// Manages the application's music state, including search, playback, and local files.
class MusicProvider with ChangeNotifier {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final YoutubeExplode _yt = YoutubeExplode();

  AudioHandler? _audioHandler;
  AudioHandler? get audioHandler => _audioHandler;

  final Map<String, Uint8List> _artworkCache = {};

  List<Song> _searchResults = [];
  List<Song> get searchResults => _searchResults;

  List<AlbumModel> _localAlbums = [];
  List<AlbumModel> get localAlbums => _localAlbums;

  List<Song> _localSongs = [];
  List<Song> get localSongs => _localSongs;

  List<Song> _shuffledSongs = [];

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String? _loadingSongId;
  String? get loadingSongId => _loadingSongId;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isFetchingLocal = true;
  bool get isFetchingLocal => _isFetchingLocal;

  bool _isPlayerExpanded = false;
  bool get isPlayerExpanded => _isPlayerExpanded;

  bool _isShuffleEnabled = false;
  bool get isShuffleEnabled => _isShuffleEnabled;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceRepeatMode get repeatMode => _repeatMode;

  MusicProvider() {
    _init();
  }

  Future<void> _init() async {
    _audioHandler = await initAudioService();
    _audioHandler?.playbackState.listen((playbackState) {
      if (_repeatMode != playbackState.repeatMode) {
        _repeatMode = playbackState.repeatMode;
        notifyListeners();
      }
    });
    fetchLocalMusic();
  }

  void clearError() {
    _errorMessage = null;
  }

  Future<void> fetchLocalMusic() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      if (await Permission.audio.request().isGranted || await Permission.storage.request().isGranted) {
        List<AlbumModel> albums = await _audioQuery.queryAlbums(
          sortType: AlbumSortType.ALBUM,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        _localAlbums = albums;
        _localSongs = songs
            .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 10000)
            .map((s) => Song(
                  id: s.uri!,
                  title: s.title,
                  artist: s.artist ?? "Unknown",
                  thumbUrl: "",
                  type: 'local',
                  localId: s.id,
                  albumId: s.albumId,
                  duration: Duration(milliseconds: s.duration ?? 0),
                ))
            .toList();

        _shuffledSongs = List.from(_localSongs)..shuffle();

        if (_audioHandler != null) {
          await _updateQueueWithSongs(_isShuffleEnabled ? _shuffledSongs : _localSongs);
        }
      }
    } catch (e) {
      print("Error fetching local music: $e");
       _errorMessage = "Error fetching local music.";
       notifyListeners();
    } finally {
      _isFetchingLocal = false;
      notifyListeners();
    }
  }

  Future<List<Song>> getLocalSongsByAlbum(int albumId) async {
    List<SongModel> albumSongs = await _audioQuery.queryAudiosFrom(
      AudiosFromType.ALBUM_ID,
      albumId,
      orderType: OrderType.ASC_OR_SMALLER,
    );

    albumSongs.sort((a, b) {
      int trackA = int.tryParse(a.track.toString()) ?? 0;
      int trackB = int.tryParse(b.track.toString()) ?? 0;
      return trackA.compareTo(trackB);
    });

    return albumSongs
        .where((s) => (s.isMusic ?? false) && (s.duration ?? 0) > 10000)
        .map((s) => Song(
              id: s.uri!,
              title: s.title,
              artist: s.artist ?? "Unknown",
              thumbUrl: "",
              type: 'local',
              localId: s.id,
              albumId: s.albumId,
              duration: Duration(milliseconds: s.duration ?? 0),
            ))
        .toList();
  }

  Future<Uint8List?> getArtwork(int id, ArtworkType type) async {
    final String cacheKey = '${type.toString()}_$id';
    if (_artworkCache.containsKey(cacheKey)) return _artworkCache[cacheKey];

    final Uint8List? artwork = await _audioQuery.queryArtwork(id, type, format: ArtworkFormat.PNG, size: 2048);
    if (artwork != null) _artworkCache[cacheKey] = artwork;
    return artwork;
  }

  Future<void> search(String query) async {
    if (query.isEmpty) return;
    _isSearching = true;
    _searchResults.clear();
    notifyListeners();

    try {
      final searchResult = await _yt.search.getVideos(query);
      final List<Song> songs = [];
      for (var video in searchResult) {
        songs.add(Song(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          thumbUrl: video.thumbnails.highResUrl,
          type: 'youtube',
          duration: video.duration,
        ));
      }
      _searchResults = songs;
    } catch (e) {
       _errorMessage = "Failed to get search results.";
       notifyListeners();
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

 Future<void> play(Song song, {List<Song>? newQueue}) async {
    if (_audioHandler == null) return;

    try {
      _loadingSongId = song.id;
      notifyListeners();

      if (song.type == 'youtube') {
        var manifest = await _yt.videos.streamsClient.getManifest(song.id);
        var streamInfo = manifest.audioOnly.withHighestBitrate();
        
        // Get the actual byte stream and convert it to Uint8List
        var stream = _yt.videos.streamsClient.get(streamInfo);
        var completer = Completer<Uint8List>();
        var builder = BytesBuilder();
        stream.listen(
          builder.add,
          onError: completer.completeError,
          onDone: () => completer.complete(builder.toBytes()),
        );
        final bytes = await completer.future;

        final mediaItem = _songToMediaItem(song);
        await (_audioHandler! as MyAudioHandler).playYoutubeStream(mediaItem, bytes);

      } else {
          // This is the original, untouched logic for local music.
          List<Song> queueToPlay = newQueue ?? (_isShuffleEnabled ? _shuffledSongs : _localSongs);
          if (newQueue != null) {
            await _updateQueueWithSongs(queueToPlay);
          }
          
          final index = queueToPlay.indexWhere((s) => s.id == song.id);
          if (index != -1) {
            await _audioHandler!.skipToQueueItem(index);
            await _audioHandler!.play();
          }
      }

      if (!_isPlayerExpanded) {
        _isPlayerExpanded = true;
      }
    } catch (e, s) {
      print("--- DETAILED PLAYBACK ERROR ---");
      print(e);
      print(s);
      print("---------------------------------");

      if (e is VideoUnplayableException) {
        _errorMessage = "Video is unplayable.";
      } else if (e is VideoUnavailableException) {
        _errorMessage = "Video is unavailable.";
      } else {
        _errorMessage = "Failed to fetch audio stream.";
      }

    } finally {
       _loadingSongId = null;
       notifyListeners();
    }
  }

  Future<void> _updateQueueWithSongs(List<Song> songs) async {
    final mediaItems = songs.map((s) => _songToMediaItem(s)).toList();
    await _audioHandler!.updateQueue(mediaItems);
  }

  MediaItem _songToMediaItem(Song s) {
    return MediaItem(
      id: s.id, // The ID is now the YouTube video ID or the local file URI
      album: s.type == 'local' ? "Local Music" : "YouTube",
      title: s.title,
      artist: s.artist,
      artUri: s.type == 'youtube' ? Uri.parse(s.thumbUrl) : null,
      genre: s.type,
      duration: s.duration,
      extras: {'artworkId': s.localId, 'albumId': s.albumId, 'videoId': s.id},
    );
  }

  void togglePlayPause() {
    _audioHandler?.playbackState.value.playing == true ? _audioHandler!.pause() : _audioHandler!.play();
  }

  void next() => _audioHandler?.skipToNext();
  void previous() => _audioHandler?.skipToPrevious();
  void seek(Duration pos) => _audioHandler?.seek(pos);

  void cycleRepeatMode() {
    if (_audioHandler == null) return;
    final nextMode = {
      AudioServiceRepeatMode.none: AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all: AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one: AudioServiceRepeatMode.none,
    }[_repeatMode];

    if (nextMode != null) {
      _repeatMode = nextMode;
      notifyListeners(); 
      _audioHandler!.setRepeatMode(nextMode);
    }
  }

  void toggleShuffle() {
    if (_audioHandler == null) return;
    _isShuffleEnabled = !_isShuffleEnabled;
    final newMode = _isShuffleEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
    _audioHandler!.setShuffleMode(newMode);

    if (_isShuffleEnabled) {
      _shuffledSongs = List.from(_localSongs)..shuffle();
      _updateQueueWithSongs(_shuffledSongs);
    } else {
      _updateQueueWithSongs(_localSongs);
    }

    notifyListeners();
  }

  void togglePlayerView() {
    _isPlayerExpanded = !_isPlayerExpanded;
    notifyListeners();
  }

  void collapsePlayer() {
    if (_isPlayerExpanded) {
      _isPlayerExpanded = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
