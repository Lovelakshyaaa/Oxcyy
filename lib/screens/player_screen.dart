import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:oxcy/providers/music_provider.dart';

// Main SmartPlayer widget: Handles the overall structure and animations.
class SmartPlayer extends StatelessWidget {
  const SmartPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioHandler = context.read<MusicProvider>().audioHandler;
    if (audioHandler == null) return const SizedBox.shrink();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem.distinct(),
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return Selector<MusicProvider, bool>(
          selector: (_, provider) => provider.isPlayerExpanded,
          builder: (context, isPlayerExpanded, _) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: isPlayerExpanded ? MediaQuery.of(context).size.height : 70.0,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: isPlayerExpanded
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10)
                ],
              ),
              child: isPlayerExpanded
                  ? FullPlayerView(mediaItem: mediaItem, audioHandler: audioHandler)
                  : MiniPlayerView(mediaItem: mediaItem, audioHandler: audioHandler),
            );
          },
        );
      },
    );
  }
}

// MiniPlayerView: Optimized for the collapsed state.
class MiniPlayerView extends StatelessWidget {
  final MediaItem mediaItem;
  final AudioHandler audioHandler;

  const MiniPlayerView({Key? key, required this.mediaItem, required this.audioHandler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<MusicProvider>().togglePlayerView(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.transparent,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _Artwork(mediaItem: mediaItem, size: 45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(mediaItem.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(mediaItem.artist ?? '', maxLines: 1, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            // This is the only part of the mini-player that needs to rebuild on playback state changes.
            _MiniPlayerControls(audioHandler: audioHandler),
          ],
        ),
      ),
    );
  }
}

// FullPlayerView: The main expanded player UI, now with static and dynamic parts separated.
class FullPlayerView extends StatelessWidget {
  final MediaItem mediaItem;
  final AudioHandler audioHandler;

  const FullPlayerView({Key? key, required this.mediaItem, required this.audioHandler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Static background
        Positioned.fill(child: _Artwork(mediaItem: mediaItem, size: double.infinity, highRes: true)),
        Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(color: Colors.black.withOpacity(0.6)))),
        
        // Static UI elements
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30), onPressed: () => context.read<MusicProvider>().collapsePlayer()),
              ),
              const Spacer(),
              _HighResArtwork(mediaItem: mediaItem, size: 300),
              const SizedBox(height: 40),
              _SongInfoCard(mediaItem: mediaItem, audioHandler: audioHandler),
              const SizedBox(height: 20),
              
              // Dynamic UI elements (the controls)
              _FullPlayerControls(audioHandler: audioHandler as MyAudioHandler),
              
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

// -- STATIC WIDGETS (Rebuild only when MediaItem changes) --

class _Artwork extends StatelessWidget {
  final MediaItem mediaItem;
  final double size;
  final bool highRes;

  const _Artwork({required this.mediaItem, required this.size, this.highRes = false});

 @override
  Widget build(BuildContext context) {
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
        artworkHeight: size * (highRes ? 1.0 : 2.0),
        artworkWidth: size * (highRes ? 1.0 : 2.0),
        nullArtworkWidget: Container(
          color: Colors.grey[900],
          child: Icon(Icons.music_note, color: Colors.white, size: size * 0.5),
        ),
      );
    } else {
      return CachedNetworkImage(
        key: ValueKey(mediaItem.artUri),
        imageUrl: mediaItem.artUri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 2).toInt(),
        memCacheHeight: (size * 2).toInt(),
        errorWidget: (_, __, ___) => Container(
          color: Colors.grey[900],
          child: const Icon(Icons.music_note),
        ),
      );
    }
  }
}

class _HighResArtwork extends StatelessWidget {
  final MediaItem mediaItem;
  final double size;
  const _HighResArtwork({required this.mediaItem, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _Artwork(mediaItem: mediaItem, size: size, highRes: true),
      ),
    );
  }
}

class _SongInfoCard extends StatelessWidget {
  final MediaItem mediaItem;
  final AudioHandler audioHandler;
  const _SongInfoCard({required this.mediaItem, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(mediaItem.title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(mediaItem.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          _PositionSlider(mediaItem: mediaItem, handler: audioHandler),
        ],
      ),
    );
  }
}

// -- DYNAMIC WIDGETS (Rebuild only when PlaybackState changes) --

class _MiniPlayerControls extends StatelessWidget {
  final AudioHandler audioHandler;
  const _MiniPlayerControls({required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final processingState = state?.processingState ?? AudioProcessingState.idle;
        final isLoading = processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering;

        if (isLoading) {
          return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
        }
        return IconButton(
          icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
          onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
        );
      },
    );
  }
}

class _FullPlayerControls extends StatelessWidget {
  final MyAudioHandler audioHandler;
  const _FullPlayerControls({required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final processingState = state?.processingState ?? AudioProcessingState.idle;
        final isLoading = processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 45), onPressed: audioHandler.skipToPrevious),
            const SizedBox(width: 20),
            Container(
              decoration: BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.4), blurRadius: 15)]),
              padding: const EdgeInsets.all(5),
              child: IconButton(
                iconSize: 50,
                icon: isLoading
                    ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
              ),
            ),
            const SizedBox(width: 20),
            IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 45), onPressed: audioHandler.skipToNext),
          ],
        );
      },
    );
  }
}

// -- SLIDER WIDGET (Already optimized with its own state management) --

class _PositionSlider extends StatefulWidget {
  const _PositionSlider({required this.mediaItem, required this.handler});
  final MediaItem mediaItem;
  final AudioHandler handler;

  @override
  __PositionSliderState createState() => __PositionSliderState();
}

class __PositionSliderState extends State<_PositionSlider> {
  double? _dragValue;
  Stream<Duration> get _positionStream => AudioService.position;

  @override
  Widget build(BuildContext context) {
    final duration = widget.mediaItem.duration ?? Duration.zero;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: StreamBuilder<Duration>(
        stream: _positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final currentSliderValue = _dragValue ?? position.inMilliseconds.toDouble();
          final maxSliderValue = duration.inMilliseconds.toDouble();

          return Row(
            children: [
              Text(_formatDuration(Duration(milliseconds: currentSliderValue.round())), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: Colors.purpleAccent,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.purpleAccent,
                  ),
                  child: Slider(
                    min: 0.0,
                    max: maxSliderValue > 0 ? maxSliderValue : 1.0,
                    value: currentSliderValue.clamp(0.0, maxSliderValue),
                    onChanged: (value) => setState(() => _dragValue = value),
                    onChangeEnd: (value) {
                      widget.handler.seek(Duration(milliseconds: value.round()));
                      setState(() => _dragValue = null);
                    },
                  ),
                ),
              ),
              Text(_formatDuration(duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
