import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:oxcy/providers/music_provider.dart';

class SmartPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);
    final song = provider.currentSong;

    // ERROR LISTENER
    if (provider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!), backgroundColor: Colors.red),
        );
        provider.clearError();
      });
    }

    if (song == null || !provider.isMiniPlayerVisible) return SizedBox.shrink();

    final double screenHeight = MediaQuery.of(context).size.height;
    final double height = provider.isPlayerExpanded ? screenHeight : 70.0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: height,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A2E), 
        borderRadius: provider.isPlayerExpanded 
            ? BorderRadius.zero 
            : BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
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

  Widget _buildMiniPlayer(BuildContext context, MusicProvider provider, Song song) {
    return GestureDetector(
      onTap: provider.togglePlayerView, 
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
           color: Color(0xFF2E2E4D),
           borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: song.thumbUrl, width: 45, height: 45, fit: BoxFit.cover),
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
            // Loading Spinner or Play Button
            provider.isLoadingSong 
              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : IconButton(
                  icon: Icon(provider.player.playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: provider.togglePlayPause,
                ),
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
          Positioned.fill(child: CachedNetworkImage(imageUrl: song.thumbUrl, fit: BoxFit.cover)),
          Positioned.fill(
             child: BackdropFilter(
               filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
               child: Container(color: Colors.black.withOpacity(0.7)),
             ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30),
                    onPressed: provider.collapsePlayer, 
                  ),
                ),
                Spacer(),
                
                Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(imageUrl: song.thumbUrl, fit: BoxFit.cover),
                  ),
                ),
                
                SizedBox(height: 30),
                
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(song.title, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(song.artist, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 18)),
                    ],
                  ),
                ),
                
                SizedBox(height: 30),
                
                StreamBuilder<Duration>(
                  stream: provider.player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = provider.player.duration ?? Duration.zero;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Slider(
                            value: position.inSeconds.toDouble().clamp(0, total.inSeconds.toDouble()),
                            max: total.inSeconds.toDouble() > 0 ? total.inSeconds.toDouble() : 1, 
                            activeColor: Colors.purpleAccent,
                            onChanged: (val) => provider.player.seek(Duration(seconds: val.toInt())),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(position), style: TextStyle(color: Colors.white54)),
                                total.inSeconds == 0 
                                  ? SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white)) 
                                  : Text(_formatDuration(total), style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                       icon: Icon(Icons.shuffle, color: provider.isShuffling ? Colors.purpleAccent : Colors.white54),
                       onPressed: provider.toggleShuffle,
                    ),
                    IconButton(icon: Icon(Icons.skip_previous, color: Colors.white, size: 40), onPressed: provider.previous),
                    
                    // PLAY BUTTON WITH LOADER
                    Container(
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: provider.isLoadingSong 
                        ? Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(color: Colors.black))
                        : IconButton(
                            iconSize: 50,
                            icon: Icon(provider.player.playing ? Icons.pause : Icons.play_arrow, color: Colors.black),
                            onPressed: provider.togglePlayPause,
                          ),
                    ),
                    
                    IconButton(icon: Icon(Icons.skip_next, color: Colors.white, size: 40), onPressed: provider.next),
                    IconButton(
                       icon: Icon(
                         provider.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat, 
                         color: provider.loopMode != LoopMode.off ? Colors.purpleAccent : Colors.white54
                       ),
                       onPressed: provider.toggleLoop,
                    ),
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
