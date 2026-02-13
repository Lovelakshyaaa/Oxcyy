import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/providers/music_provider.dart';

class SmartPlayer extends StatelessWidget {
  const SmartPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uiProvider = Provider.of<MusicProvider>(context);
    final audioHandler = uiProvider.audioHandler;

    if (audioHandler == null) return const SizedBox.shrink();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        final double screenHeight = MediaQuery.of(context).size.height;
        final double height = uiProvider.isPlayerExpanded ? screenHeight : 70.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: uiProvider.isPlayerExpanded
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, playbackStateSnapshot) {
              final state = playbackStateSnapshot.data;
              final playing = state?.playing ?? false;
              final processingState =
                  state?.processingState ?? AudioProcessingState.idle;

              return Stack(
                children: [
                  if (uiProvider.isPlayerExpanded)
                    _buildFullScreen(context, uiProvider, audioHandler,
                        mediaItem, playing, processingState)
                  else
                    _buildMiniPlayer(context, uiProvider, audioHandler,
                        mediaItem, playing, processingState),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // 🔥 IMPROVED: Request high-res artwork by setting width/height
  Widget _buildArtwork(MediaItem mediaItem, double size, {bool highRes = false}) {
    final isLocal = mediaItem.genre == 'local';
    if (isLocal) {
      final artworkId = mediaItem.extras?['artworkId'] as int?;
      if (artworkId == null) {
        return Container(
          color: Colors.grey[900],
          child: Icon(Icons.music_note, color: Colors.white, size: size * 0.5),
        );
      }
      return QueryArtworkWidget(
        id: artworkId,
        type: ArtworkType.AUDIO,
        keepOldArtwork: true,
        quality: 100,
        artworkQuality: FilterQuality.high,
        artworkHeight: size.toInt(),   // 🔥 NEW: request exact size
        artworkWidth: size.toInt(),    // 🔥 NEW: request exact size
        nullArtworkWidget: Container(
          color: Colors.grey[900],
          child: Icon(Icons.music_note, color: Colors.white, size: size * 0.5),
        ),
      );
    } else {
      return CachedNetworkImage(
        imageUrl: mediaItem.artUri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[900],
          child: const Icon(Icons.music_note),
        ),
      );
    }
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    MusicProvider uiProvider,
    AudioHandler handler,
    MediaItem mediaItem,
    bool playing,
    AudioProcessingState processingState,
  ) {
    final bool isLoading = processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;

    return GestureDetector(
      onTap: uiProvider.togglePlayerView,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildArtwork(mediaItem, 45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mediaItem.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    mediaItem.artist ?? '',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              IconButton(
                icon: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.white),
                onPressed: () =>
                    playing ? handler.pause() : handler.play(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreen(
    BuildContext context,
    MusicProvider uiProvider,
    AudioHandler handler,
    MediaItem mediaItem,
    bool playing,
    AudioProcessingState processingState,
  ) {
    final bool isLoading = processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;
    final queueHandler = handler as QueueHandler;

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildArtwork(mediaItem, double.infinity, highRes: true),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 30),
                    onPressed: uiProvider.collapsePlayer,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 30,
                          offset: Offset(0, 10))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildArtwork(mediaItem, 300, highRes: true),
                  ),
                ),
                const SizedBox(height: 40),
                GlassmorphicContainer(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 180,
                  borderRadius: 20,
                  blur: 15,
                  alignment: Alignment.center,
                  border: 1,
                  linearGradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.white.withOpacity(0.05)
                    ],
                  ),
                  borderGradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1)
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        mediaItem.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        mediaItem.artist ?? '',
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<Duration>(
                        stream: AudioService.position,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final duration = mediaItem.duration ?? Duration.zero; // now has value!
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: position.inMilliseconds
                                        .toDouble()
                                        .clamp(0.0,
                                            duration.inMilliseconds.toDouble()),
                                    max: duration.inMilliseconds > 0
                                        ? duration.inMilliseconds.toDouble()
                                        : 1.0,
                                    activeColor: Colors.purpleAccent,
                                    inactiveColor: Colors.white10,
                                    onChanged: (val) => handler.seek(
                                        Duration(milliseconds: val.toInt())),
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white, size: 45),
                      onPressed: queueHandler.skipToPrevious,
                    ),
                    const SizedBox(width: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.purple.withOpacity(0.4),
                              blurRadius: 15)
                        ],
                      ),
                      padding: const EdgeInsets.all(5),
                      child: IconButton(
                        iconSize: 50,
                        icon: isLoading
                            ? const SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 3))
                            : Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white),
                        onPressed: () =>
                            playing ? handler.pause() : handler.play(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 45),
                      onPressed: queueHandler.skipToNext,
                    ),
                  ],
                ),
                const Spacer(),
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
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}
