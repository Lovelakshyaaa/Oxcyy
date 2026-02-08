import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart'; // REQUIRED for Local Art
import 'package:google_fonts/google_fonts.dart';
import 'package:oxcy/providers/music_provider.dart';

class SmartPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);
    final song = provider.currentSong;

    if (song == null || !provider.isMiniPlayerVisible) return SizedBox.shrink();

    final double screenHeight = MediaQuery.of(context).size.height;
    final double height = provider.isPlayerExpanded ? screenHeight : 70.0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: height,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A2E), 
        borderRadius: provider.isPlayerExpanded ? BorderRadius.zero : BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: Stack(
        children: [
          if (provider.isPlayerExpanded) _buildFullScreen(context, provider, song),
          if (!provider.isPlayerExpanded) _buildMiniPlayer(context, provider, song),
        ],
      ),
    );
  }

  // -----------------------------------------------------------
  // HELPER: ARTWORK BUILDER (Smart Switcher)
  // -----------------------------------------------------------
  Widget _buildArtwork(Song song, double size) {
    if (song.type == 'local' && song.localId != null) {
      return SizedBox(
        width: size, height: size,
        child: QueryArtworkWidget(
          id: song.localId!,
          type: ArtworkType.AUDIO,
          keepOldArtwork: true,
          nullArtworkWidget: Container(color: Colors.grey[900], child: Icon(Icons.music_note, color: Colors.white)),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: song.thumbUrl,
        width: size, height: size,
        fit: BoxFit.cover,
        errorWidget: (_,__,___) => Container(color: Colors.grey[900], child: Icon(Icons.music_note)),
      );
    }
  }

  // MINI PLAYER
  Widget _buildMiniPlayer(BuildContext context, MusicProvider provider, Song song) {
    return GestureDetector(
      onTap: provider.togglePlayerView, 
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildArtwork(song, 45), // Uses Smart Switcher
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(song.artist, maxLines: 1, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            provider.isLoadingSong 
              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : IconButton(
                  icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: provider.togglePlayPause,
                ),
          ],
        ),
      ),
    );
  }

  // FULL SCREEN
  Widget _buildFullScreen(BuildContext context, MusicProvider provider, Song song) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurry Background
          Positioned.fill(child: _buildArtwork(song, double.infinity)),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: Container(color: Colors.black.withOpacity(0.7)))),
          
          SafeArea(
            child: Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: IconButton(icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30), onPressed: provider.collapsePlayer)),
                Spacer(),
                
                // Big Artwork
                Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20)]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _buildArtwork(song, 300)),
                ),
                
                SizedBox(height: 30),
                Text(song.title, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                Text(song.artist, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 18)),
                
                SizedBox(height: 30),
                
                // Slider
                Slider(
                  value: provider.position.inSeconds.toDouble().clamp(0, provider.duration.inSeconds.toDouble()),
                  max: provider.duration.inSeconds.toDouble() > 0 ? provider.duration.inSeconds.toDouble() : 1, 
                  activeColor: Colors.purpleAccent,
                  onChanged: (val) => provider.seek(Duration(seconds: val.toInt())),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: Icon(Icons.skip_previous, color: Colors.white, size: 40), onPressed: provider.previous),
                    SizedBox(width: 20),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: provider.isLoadingSong 
                        ? Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(color: Colors.black))
                        : IconButton(iconSize: 50, icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.black), onPressed: provider.togglePlayPause),
                    ),
                    SizedBox(width: 20),
                    IconButton(icon: Icon(Icons.skip_next, color: Colors.white, size: 40), onPressed: provider.next),
                  ],
                ),
                Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
