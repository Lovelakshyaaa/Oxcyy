import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'player_screen.dart'; // To open the player

class LocalMusicScreen extends StatefulWidget {
  @override
  _LocalMusicScreenState createState() => _LocalMusicScreenState();
}

class _LocalMusicScreenState extends State<LocalMusicScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  Future<void> _fetchSongs() async {
    try {
      // 1. Request Permissions (Android 13+ friendly)
      if (await Permission.audio.request().isGranted || 
          await Permission.storage.request().isGranted) {
        
        // 2. Query Songs Direct from Storage
        List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.DATE_ADDED,
          orderType: OrderType.DESC_OR_GREATER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        // 3. Filter short audio (under 10s)
        setState(() {
          _songs = songs.where((i) => (i.isMusic == true) && (i.duration ?? 0) > 10000).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching songs: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We only use Provider to get the HEADER (The AudioHandler instance)
    // We do NOT use it for logic anymore.
    final handler = Provider.of<MusicProvider>(context, listen: false).audioHandler;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("My Music", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            
            if (_isLoading)
              Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
            else if (_songs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off, size: 80, color: Colors.white24),
                      SizedBox(height: 10),
                      Text("No local songs found", style: TextStyle(color: Colors.white54)),
                      TextButton(
                        onPressed: _fetchSongs, 
                        child: Text("Refresh", style: TextStyle(color: Colors.purpleAccent))
                      )
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 100), 
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      
                      // ALBUM ART
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 50, 
                          height: 50,
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            keepOldArtwork: true, 
                            nullArtworkWidget: Container(
                              color: Colors.white10,
                              child: Icon(Icons.music_note, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      
                      // TITLE & ARTIST
                      title: Text(
                        song.title, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)
                      ),
                      subtitle: Text(
                        song.artist ?? "Unknown", 
                        maxLines: 1, 
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)
                      ),
                      
                      // ⚠️ THE FIX: DIRECT INJECTION INTO AUDIO HANDLER
                      onTap: () async {
                        if (handler != null) {
                          // 1. Create the MediaItem locally with the Fix applied
                          final mediaItem = MediaItem(
                            // Use song.uri (with fallback) to prevent path issues
                            id: song.uri ?? "content://media/external/audio/media/${song.id}", 
                            title: song.title,
                            artist: song.artist ?? "Unknown Artist",
                            duration: Duration(milliseconds: song.duration ?? 0),
                            genre: 'local', // Required for fix
                            
                            // *** CRITICAL CHANGE: Adding artworkId ***
                            // We keep localId too so your PlayerScreen doesn't break
                            extras: {
                              'artworkId': song.id, 
                              'localId': song.id
                            },
                          );

                          // 2. Send directly to Engine (Bypassing Provider Logic)
                          await handler.playMediaItem(mediaItem);

                          // 3. Open Player UI
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SmartPlayer(audioHandler: handler),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
