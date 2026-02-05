import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oxcy/providers/music_provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // INFINITE SCROLL LISTENER
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        Provider.of<MusicProvider>(context, listen: false).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 20),
                child: Text("OXCY Music", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.white.withOpacity(0.1),
                      child: TextField(
                        controller: _controller,
                        style: GoogleFonts.poppins(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Search songs & albums...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white54),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.clear, color: Colors.white54),
                            onPressed: () => _controller.clear(),
                          ),
                        ),
                        onSubmitted: (val) async {
                          if (val.trim().isEmpty) return;
                          // Dismiss keyboard
                          FocusScope.of(context).unfocus();
                          await musicProvider.search(val);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              
              // Search Results
              Expanded(
                child: musicProvider.searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_note_outlined, size: 60, color: Colors.white24),
                          SizedBox(height: 10),
                          Text("Search for music...", style: TextStyle(color: Colors.white24)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController, // Attach Scroll Controller
                      padding: EdgeInsets.only(bottom: 100),
                      itemCount: musicProvider.searchResults.length + (musicProvider.isFetchingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show Loading Spinner at bottom
                        if (index == musicProvider.searchResults.length) {
                          return Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()));
                        }

                        final song = musicProvider.searchResults[index];
                        final isAlbum = song.type == 'playlist';

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: song.thumbUrl,
                                  width: 50, height: 50, fit: BoxFit.cover,
                                ),
                              ),
                              // Show Disc icon if it's an Album
                              if (isAlbum)
                                Container(
                                  width: 50, height: 50,
                                  color: Colors.black54,
                                  child: Icon(Icons.album, color: Colors.white),
                                )
                            ],
                          ),
                          title: Text(
                            song.title, 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis, 
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: isAlbum ? FontWeight.bold : FontWeight.normal)
                          ),
                          subtitle: Text(
                            isAlbum ? "Album • ${song.artist}" : "Song • ${song.artist}", 
                            style: GoogleFonts.poppins(color: Colors.white70)
                          ),
                          onTap: () {
                            if (isAlbum) {
                              musicProvider.playPlaylist(song);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Loading Album...")));
                            } else {
                              musicProvider.play(song);
                            }
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
