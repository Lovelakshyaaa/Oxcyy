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
          key: ValueKey(mediaItem.id),
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
        keepOldArtwork: false,
        quality: 100,
        artworkQuality: FilterQuality.high,
        artworkHeight: size * 2.0,
        artworkWidth: size * 2.0,
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
                // HIGH‑RESOLUTION ALBUM ARTWORK
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
                    child: _HighResArtwork(mediaItem: mediaItem, size: 300),
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
                      _PositionSlider(mediaItem: mediaItem, handler: handler),
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

// ==================== HIGH‑RESOLUTION ARTWORK ====================
class _HighResArtwork extends StatefulWidget {
  final MediaItem mediaItem;
  final double size;

  const _HighResArtwork({required this.mediaItem, required this.size});

  @override
  __HighResArtworkState createState() => __HighResArtworkState();
}

class __HighResArtworkState extends State<_HighResArtwork> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  Uint8List? _artworkBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaItem.genre == 'local') {
      _loadLocalArtwork();
    }
  }

  @override
  void didUpdateWidget(covariant _HighResArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.id != widget.mediaItem.id) {
      setState(() {
        _artworkBytes = null;
        _isLoading = false;
      });
      if (widget.mediaItem.genre == 'local') {
        _loadLocalArtwork();
      }
    }
  }

  Future<void> _loadLocalArtwork() async {
    final artworkId = widget.mediaItem.extras?['artworkId'] as int?;
    if (artworkId == null) return;

    setState(() => _isLoading = true);
    try {
      // ✅ FIXED: positional arguments id and type, then named parameters
      final artwork = await _audioQuery.queryArtwork(
        artworkId,
        ArtworkType.AUDIO,
        size: 1024,   // request large size
        quality: 100,
      );
      if (artwork != null) {
        setState(() {
          _artworkBytes = artwork;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Artwork load error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = widget.mediaItem.genre == 'local';

    if (isLocal) {
      if (_artworkBytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.memory(
            _artworkBytes!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          ),
        );
      } else if (_isLoading) {
        return Container(
          width: widget.size,
          height: widget.size,
          color: Colors.grey[900],
          child: Center(
            child: SizedBox(
              width: widget.size * 0.2,
              height: widget.size * 0.2,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else {
        return Container(
          width: widget.size,
          height: widget.size,
          color: Colors.grey[900],
          child: Icon(Icons.music_note, color: Colors.white, size: widget.size * 0.3),
        );
      }
    } else {
      // YouTube
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: widget.mediaItem.artUri.toString(),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          memCacheWidth: widget.size.toInt() * 2,
          memCacheHeight: widget.size.toInt() * 2,
          placeholder: (context, url) => Container(
            color: Colors.grey[900],
            child: Center(
              child: SizedBox(
                width: widget.size * 0.2,
                height: widget.size * 0.2,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[900],
            child: Icon(Icons.music_note, color: Colors.white, size: widget.size * 0.3),
          ),
        ),
      );
    }
  }
}

// ==================== FIXED SLIDER ====================
class _PositionSlider extends StatefulWidget {
  const _PositionSlider({required this.mediaItem, required this.handler});

  final MediaItem mediaItem;
  final AudioHandler handler;

  @override
  __PositionSliderState createState() => __PositionSliderState();
}

class __PositionSliderState extends State<_PositionSlider> {
  double? _dragValue;
  late final Stream<Duration> _positionStream;

  @override
  void initState() {
    super.initState();
    _positionStream = AudioService.position
        .throttleTime(const Duration(milliseconds: 500))
        .distinct();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.mediaItem.duration ?? Duration.zero;
    final bool durationKnown = duration.inMilliseconds > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Current position display
          StreamBuilder<Duration>(
            stream: _positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final displayPosition = _dragValue != null
                  ? Duration(milliseconds: _dragValue!.toInt())
                  : position;
              return Text(
                _formatDuration(displayPosition),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              );
            },
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: StreamBuilder<Duration>(
                stream: _positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final currentValue = _dragValue ?? position.inMilliseconds.toDouble();
                  return Slider(
                    value: currentValue.clamp(0, duration.inMilliseconds.toDouble()),
                    min: 0,
                    max: durationKnown ? duration.inMilliseconds.toDouble() : 1,
                    activeColor: Colors.purpleAccent,
                    inactiveColor: Colors.white10,
                    onChanged: durationKnown
                        ? (value) {
                            setState(() => _dragValue = value);
                          }
                        : null,
                    onChangeEnd: (value) {
                      setState(() => _dragValue = null);
                      widget.handler.seek(Duration(milliseconds: value.toInt()));
                    },
                  );
                },
              ),
            ),
          ),
          // Total duration
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
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
