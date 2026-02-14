import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/providers/music_provider.dart';

class SmartPlayer extends StatefulWidget {
  const SmartPlayer({Key? key}) : super(key: key);

  @override
  State<SmartPlayer> createState() => _SmartPlayerState();
}

class _SmartPlayerState extends State<SmartPlayer> {
  MediaItem? _currentMediaItem;
  StreamSubscription? _mediaItemSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audioHandler = context.read<MusicProvider>().audioHandler;
    if (audioHandler != null && _mediaItemSubscription == null) {
      _mediaItemSubscription = audioHandler.mediaItem.distinct().listen((mediaItem) {
        if (mediaItem != null) {
          setState(() {
            _currentMediaItem = mediaItem;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _mediaItemSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = context.read<MusicProvider>().audioHandler;
    if (audioHandler == null || _currentMediaItem == null) {
      return const SizedBox.shrink();
    }

    return Selector<MusicProvider, bool>(
      selector: (_, provider) => provider.isPlayerExpanded,
      builder: (context, isPlayerExpanded, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isPlayerExpanded ? MediaQuery.of(context).size.height : 70.0,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: isPlayerExpanded ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: isPlayerExpanded
              ? FullPlayerView(mediaItem: _currentMediaItem!, audioHandler: audioHandler)
              : MiniPlayerView(mediaItem: _currentMediaItem!, audioHandler: audioHandler),
        );
      },
    );
  }
}

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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _Artwork(key: ValueKey(mediaItem.id), mediaItem: mediaItem, size: 45),
              ),
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
            _MiniPlayerControls(audioHandler: audioHandler),
          ],
        ),
      ),
    );
  }
}

class FullPlayerView extends StatelessWidget {
  final MediaItem mediaItem;
  final AudioHandler audioHandler;

  const FullPlayerView({Key? key, required this.mediaItem, required this.audioHandler}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 750),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: _HighResArtwork(key: ValueKey(mediaItem.id), mediaItem: mediaItem, isBackground: true),
          ),
        ),
        Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(color: Colors.black.withOpacity(0.6)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 30), onPressed: () => context.read<MusicProvider>().collapsePlayer()),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 750),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: _HighResArtwork(key: ValueKey(mediaItem.id), mediaItem: mediaItem, size: 300),
                ),
                const SizedBox(height: 40),
                _SongInfoCard(mediaItem: mediaItem, audioHandler: audioHandler),
                const SizedBox(height: 20),
                _FullPlayerControls(audioHandler: audioHandler),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  final MediaItem mediaItem;
  final double size;

  const _Artwork({Key? key, required this.mediaItem, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (mediaItem.artUri != null) {
      return CachedNetworkImage(
        imageUrl: mediaItem.artUri.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => _defaultArtwork(size: size),
        errorWidget: (_, __, ___) => _defaultArtwork(size: size),
      );
    }
    
    final artworkId = mediaItem.extras?['artworkId'] as int?;
    if (artworkId == null) return _defaultArtwork(size: size);

    return QueryArtworkWidget(
      id: artworkId,
      type: ArtworkType.AUDIO,
      keepOldArtwork: true,
      artworkQuality: FilterQuality.high,
      artworkHeight: size,
      artworkWidth: size,
      artworkFit: BoxFit.cover,
      nullArtworkWidget: _defaultArtwork(size: size),
    );
  }

  Widget _defaultArtwork({double? size}) => Container(width: size, height: size, color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.white));
}

// FIX: Convert to StatefulWidget to prevent flicker
class _HighResArtwork extends StatefulWidget {
  final MediaItem mediaItem;
  final double? size;
  final bool isBackground;

  const _HighResArtwork({Key? key, required this.mediaItem, this.size, this.isBackground = false}) : super(key: key);

  @override
  __HighResArtworkState createState() => __HighResArtworkState();
}

class __HighResArtworkState extends State<_HighResArtwork> {
  Uint8List? _artworkData;

  @override
  void initState() {
    super.initState();
    _fetchArtwork();
  }

  @override
  void didUpdateWidget(covariant _HighResArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaItem.id != oldWidget.mediaItem.id) {
      _fetchArtwork();
    }
  }

  Future<void> _fetchArtwork() async {
    final provider = context.read<MusicProvider>();
    final albumId = widget.mediaItem.extras?['albumId'] as int?;
    if (albumId == null) {
      if (mounted) setState(() => _artworkData = null);
      return;
    }
    final data = await provider.getArtwork(albumId, ArtworkType.ALBUM);
    if (mounted) {
      setState(() => _artworkData = data);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_artworkData != null) {
      final image = MemoryImage(_artworkData!);
      if (widget.isBackground) {
        return Image(image: image, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))],
          image: DecorationImage(image: image, fit: BoxFit.cover),
        ),
      );
    }
    // Show placeholder only if there's no artwork yet
    return _defaultArtwork(size: widget.size);
  }

  Widget _defaultArtwork({double? size}) => Container(width: size, height: size, color: Colors.grey[900], child: const Icon(Icons.album, color: Colors.white, size: 50));
}

class _SongInfoCard extends StatelessWidget {
  final MediaItem mediaItem;
  final AudioHandler audioHandler;
  const _SongInfoCard({required this.mediaItem, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return GlassmorphicContainer(
      width: double.infinity,
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: Text(mediaItem.title, key: ValueKey(mediaItem.title), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: Text(mediaItem.artist ?? '', key: ValueKey(mediaItem.artist), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 10),
          _PositionSlider(mediaItem: mediaItem, handler: audioHandler),
        ],
      ),
    );
  }
}

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
  final AudioHandler audioHandler;
  const _FullPlayerControls({required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    final musicProvider = context.watch<MusicProvider>();

    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final processingState = state?.processingState ?? AudioProcessingState.idle;
        final isLoading = processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering;
        
        // FIX: Use optimistic repeatMode from provider for instant UI feedback
        final repeatMode = musicProvider.repeatMode;
        final isShuffleEnabled = musicProvider.isShuffleEnabled;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.shuffle, color: isShuffleEnabled ? Colors.purpleAccent : Colors.white),
              onPressed: musicProvider.toggleShuffle,
            ),
            IconButton(icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 45), onPressed: audioHandler.skipToPrevious),
            Container(
              width: 70, 
              height: 70,
              decoration: BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.4), blurRadius: 15)]),
              child: IconButton(
                iconSize: 50,
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isLoading
                      ? Container(key: const ValueKey('loader'), width: 50, height: 50, padding: const EdgeInsets.all(10.0), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, key: const ValueKey('play_pause'), color: Colors.white),
                ),
                onPressed: () => playing ? audioHandler.pause() : audioHandler.play(),
              ),
            ),
            IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 45), onPressed: audioHandler.skipToNext),
            IconButton(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.one ? Icons.repeat_one : Icons.repeat,
                color: repeatMode != AudioServiceRepeatMode.none ? Colors.purpleAccent : Colors.white,
              ),
              onPressed: musicProvider.cycleRepeatMode,
            ),
          ],
        );
      },
    );
  }
}

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
