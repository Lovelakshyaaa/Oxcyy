import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oxcy/providers/music_provider.dart';

class LocalMusicScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);

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
            
            if (provider.isFetchingLocal)
              Expanded(child: Center(child: CircularProgressIndicator()))
            else if (provider.localSongs.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off, size: 80, color: Colors.white24),
                      SizedBox(height: 10),
                      Text("No local songs found", style: TextStyle(color: Colors.white54)),
                      TextButton(
                        onPressed: provider.fetchLocalSongs, 
                        child: Text("Refresh")
                      )
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: 100), // Space for MiniPlayer
                  itemCount: provider.localSongs.length,
                  itemBuilder: (context, index) {
                    final song = provider.localSongs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      // ⚠️ THE FIX: Robust Album Art Handling ⚠️
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 50, 
                          height: 50,
                          child: QueryArtworkWidget(
                            id: song.localId!,
                            type: ArtworkType.AUDIO,
                            keepOldArtwork: true, // Prevents flickering
                            nullArtworkWidget: Container(
                              color: Colors.white10,
                              child: Icon(Icons.music_note, color: Colors.white),
                            ),
                            errorBuilder: (context, exception, stackTrace) {
                              // Fallback if artwork fails to load
                              return Container(
                                color: Colors.white10,
                                child: Icon(Icons.music_note, color: Colors.white),
                              );
                            },
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
                        song.artist, 
                        maxLines: 1, 
                        style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)
                      ),
                      onTap: () {
                        // Plays the song (Provider handles logic)
                        provider.play(song);
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
