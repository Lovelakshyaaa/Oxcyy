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
  
  // No local state needed for results anymore, the Provider manages it!

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);

    // If player is full screen, we hide the home screen content slightly to save resources
    // but we keep it in the tree so it doesn't lose state.
    
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
                          hintText: "Search songs, artist...",
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
                          await musicProvider.search(val);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              
              // Results List
              Expanded(
                child: musicProvider.queue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_note_outlined, size: 60, color: Colors.white24),
                          SizedBox(height: 10),
                          Text("Search to start listening", style: TextStyle(color: Colors.white24)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: 100), // Space for Mini Player
                      itemCount: musicProvider.queue.length,
                      itemBuilder: (context, index) {
                        final song = musicProvider.queue[index];
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: song.thumbUrl,
                              width: 50, height: 50, fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: Colors.white)),
                          subtitle: Text(song.artist, style: GoogleFonts.poppins(color: Colors.white70)),
                          onTap: () {
                            musicProvider.play(song);
                            // NOTE: We do NOT use Navigator.push anymore.
                            // The Provider handles the state, and the Stack in MainScaffold shows the player.
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
