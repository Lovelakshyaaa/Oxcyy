import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart'; // The Core Player (0.10.5)
import 'package:on_audio_query/on_audio_query.dart'; // File Finder
import 'package:permission_handler/permission_handler.dart';

// ====================================================================
// DATA MODEL
// ====================================================================

class Song {
  final String id;        // File Path
  final String title;
  final String artist;
  final int? localId;     // For Artwork

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.localId,
  });
}

// ====================================================================
// MUSIC PROVIDER (RAW ENGINE)
// ====================================================================

class MusicProvider with ChangeNotifier {
  final _player = AudioPlayer(); // This is the new 0.10.5 player
  final _audioQuery = OnAudioQuery();

  List<Song> _localSongs = [];
  bool _isFetchingLocal = false;
  
  // Player State
  bool _isPlaying = false;
  Song? _currentSong;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Getters
  List<Song> get localSongs => _localSongs;
  bool get isFetchingLocal => _isFetchingLocal;
  bool get isPlaying => _isPlaying;
  Song? get currentSong => _currentSong;
  Duration get duration => _duration;
  Duration get position => _position;
  AudioPlayer get player => _player; // Expose for slider

  MusicProvider() {
    _setupPlayerListeners();
    // Delay fetch to let the UI settle
    Future.delayed(Duration(milliseconds: 500), fetchLocalSongs);
  }

  void _setupPlayerListeners() {
    // Listen to Position
    _player.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    // Listen to Duration
    _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });

    // Listen to Player State (Playing/Paused/Completed)
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
      notifyListeners();
    });
  }

  // ====================================================================
  // 1. FETCH LOCAL FILES
  // ====================================================================

  Future<void> fetchLocalSongs() async {
    _isFetchingLocal = true;
    notifyListeners();

    try {
      // Explicitly request permissions
      if (await Permission.audio.request().isGranted || 
          await Permission.storage.request().isGranted) {
        
        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        // Filter out tiny audio files (like notifications)
        _localSongs = songs
            .where((item) => (item.isMusic == true) && (item.duration ?? 0) > 10000)
            .map((item) {
          return Song(
            id: item.data, // The raw file path
            title: item.title,
            artist: item.artist ?? "Unknown",
            localId: item.id,
          );
        }).toList();
      }
    } catch (e) {
      print("Error fetching songs: $e");
    }

    _isFetchingLocal = false;
    notifyListeners();
  }

  // ====================================================================
  // 2. PLAYBACK (The Fix)
  // ====================================================================

  Future<void> play(Song song) async {
    try {
      _currentSong = song;
      notifyListeners(); // Update UI immediately
      
      // STOP whatever is happening
      await _player.stop();
      
      // CRITICAL FIX: Use setFilePath instead of setAudioSource for local files
      // This bypasses the complexity of URIs and MediaItems
      await _player.setFilePath(song.id);
      
      await _player.play();
    } catch (e) {
      print("ERROR PLAYING FILE: $e");
      // If setFilePath fails, try the URI fallback
      try {
         await _player.setAudioSource(AudioSource.file(song.id));
         await _player.play();
      } catch (e2) {
         print("FALLBACK FAILED: $e2");
      }
    }
  }

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }
}
