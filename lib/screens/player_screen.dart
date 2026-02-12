import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:audio_service/audio_service.dart'; // ⚠️ Required for AudioHandler
import 'package:oxcy/providers/music_provider.dart';

class SmartPlayer extends StatelessWidget {
  // ⚠️ THIS IS THE MISSING PIECE ⚠️
  // The compiler failed because this variable and constructor were missing.
  final AudioHandler audioHandler;

  const SmartPlayer({Key? key, required this.audioHandler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);
    final song = provider.currentSong;

    if (song == null) return SizedBox.shrink();

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
           // ⚠️ WE LISTEN TO THE ENGINE DIRECTLY HERE
           StreamBuilder<PlaybackState>(
             stream: audioHandler.playbackState,
             builder: (context, snapshot) {
               final state = snapshot.data;
               final processingState = state?.processingState ?? AudioProcessingState.idle;
               final playing = state?.playing ?? false;
               
               return Stack(
                  children: [
                      if (provider.isPlayerExpanded) 
                          _buildFullScreen(context, provider, song, audioHandler, playing, processingState),
                      if (!provider.isPlayerExpanded) 
                          _buildMiniPlayer(context, provider, song, audioHandler, playing, processingState),
                  ]
               );
             }
           ),
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
          keepOldArtwork: false,
          quality: 100,
          size: 1000,
          format: ArtworkFormat.PNG,
          key: ValueKey(song.localId.toString() + "_highres"),
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

  Widget _buildMiniPlayer(BuildContext context, MusicProvider provider, Song song, AudioHandler handler, bool playing, AudioProcessingState processingState) {
    final bool isLoading = processingState == AudioProcessingState.loading || 
                           processingState == AudioProcessingState.buffering;

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
            isLoading 
              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : IconButton(
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white), 
                  onPressed: () => playing ? handler.pause() : handler.play()
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreen(BuildContext context, MusicProvider provider, Song song, AudioHandler handler, bool playing, AudioProcessingState processingState) {
    final bool isLoading = processingState == AudioProcessingState.loading || 
                           processingState == AudioProcessingState.buffering;

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
                      
                      // REAL-TIME SEEK BAR
                      StreamBuilder<Duration>(
                        stream: AudioService.position,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = provider.duration.inMilliseconds > 0 ? provider.duration : Duration(seconds: 1);
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Text(_formatDuration(position), style: TextStyle(color: Colors.white54, fontSize: 12)),
                                Expanded(
                                  child: Slider(
                                    value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                                    max: duration.inMilliseconds.toDouble(), 
                                    activeColor: Colors.purpleAccent,
                                    inactiveColor: Colors.white10,
                                    onChanged: (val) => handler.seek(Duration(milliseconds: val.toInt())),
                                  ),
                                ),
                                Text(_formatDuration(duration), style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 45), onPressed: handler.skipToPrevious),
                    SizedBox(width: 20),
                    Container(
                      decoration: BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.4), blurRadius: 15)]),
                      padding: EdgeInsets.all(5),
                      child: IconButton(
                        iconSize: 50, 
                        icon: isLoading 
                          ? SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                        onPressed: () => playing ? handler.pause() : handler.play()
                      ),
                    ),
                    SizedBox(width: 20),
                    IconButton(icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 45), onPressed: handler.skipToNext),
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
