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
    // Get the MusicProvider instance. We will use this to play songs.
    final provider = Provider.of<MusicProvider>(context, listen: false);

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
                      
                      // *** FIXED: Now includes duration for proper slider & time display ***
                      onTap: () {
                        final songToPlay = Song(
                          id: song.uri!,
                          title: song.title,
                          artist: song.artist ?? "Unknown",
                          thumbUrl: "",
                          type: 'local',
                          localId: song.id,
                          duration: Duration(milliseconds: song.duration ?? 0),
                        );
                        provider.play(songToPlay);
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
