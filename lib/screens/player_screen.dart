import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oxcy/providers/music_provider.dart'; 

class PlayerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);
    final song = provider.currentSong;

    if (song == null) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: song.thumbUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),
          
          // UI
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(),
                // Album Art
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: song.thumbUrl,
                    width: 300, height: 300, fit: BoxFit.cover,
                  ),
                ),
                SizedBox(height: 30),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    song.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  song.artist,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
                ),
                Spacer(),
                
                // Controls
                IconButton(
                  icon: Icon(provider.player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 80),
                  onPressed: () {
                    if (provider.player.playing) {
                      provider.player.pause();
                    } else {
                      provider.player.play();
                    }
                  },
                ),
                Spacer(),
              ],
            ),
          ),
          
          // Back Button
          Positioned(
            top: 40, left: 10,
            child: IconButton(
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
