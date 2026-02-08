import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
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

  Widget _buildArtwork(Song song, double size, {bool highRes = false}) {
    if (song.type == 'local' && song.localId != null) {
      return SizedBox(
        width: size, height: size,
        child: QueryArtworkWidget(
          id: song.localId!,
          type: ArtworkType.AUDIO,
          keepOldArtwork: true,
          // ⚠️ FIX FOR BLURRY ART
          artworkQuality: FilterQuality.high,
          artworkHeight: highRes ? 1000 : 200,
          artworkWidth: highRes ? 1000 : 200,
          nullArtworkWidget: Container(
            color: Colors.grey[900], 
            child: Icon(Icons.music_note, color: Colors.white, size: size * 0.5)
          ),
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

  Widget _buildMiniPlayer(BuildContext context, MusicProvider provider, Song song) {
    return GestureDetector(
      onTap: provider.togglePlayerView, 
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildArtwork(song, 45)),
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
              : IconButton(icon: Icon(provider.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white), onPressed: provider.togglePlayPause),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreen(BuildContext context, MusicProvider provider, Song song) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: _buildArtwork(song, double.infinity, highRes: true)),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(color: Colors.black.withOpacity(0.6)))),
          
          SafeArea(
            child: Column(
              children: [
                Align(alignment: Alignment.centerLeft, child: IconButton(icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30), onPressed: provider.collapsePlayer)),
                Spacer(),
                Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _buildArtwork(song, 300, highRes: true)),
                ),
                SizedBox(height: 40),
                GlassmorphicContainer(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 180,
                  borderRadius: 20,
                  blur: 15,
                  alignment: Alignment.center,
                  border: 1,
                  linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                  borderGradient: LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)]),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(song.title, textAlign: TextAlign.center, maxLines: 1, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(song.artist, maxLines: 1, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
                      SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(_formatDuration(provider.position), style: TextStyle(color: Colors.white54, fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: provider.position.inSeconds.toDouble().clamp(0, provider.duration.inSeconds.toDouble()),
                                max: provider.duration.inSeconds.toDouble() > 0 ? provider.duration.inSeconds.toDouble() : 1, 
                                activeColor: Colors.purpleAccent,
                                inactiveColor: Colors.white10,
                                onChanged: (val) => provider.seek(Duration(seconds: val.toInt())),
                              ),
                            ),
                            Text(_formatDuration(provider.duration), style: TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 45), onPressed: provider.previous),
                    SizedBox(width: 20),
                    Container(
                      decoration: BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.4), blurRadius: 15)]),
                      padding: EdgeInsets.all(5),
                      child: IconButton(
                        iconSize: 50, 
                        icon: provider.isLoadingSong 
                          ? SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Icon(provider.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                        onPressed: provider.togglePlayPause
                      ),
                    ),
                    SizedBox(width: 20),
                    IconButton(icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 45), onPressed: provider.next),
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

  String _formatDuration(Duration d) {
    final min = d.inMinutes;
    final sec = d.inSeconds % 60;
    return '${min}:${sec.toString().padLeft(2, '0')}';
  }
}
