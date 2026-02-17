import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:oxcy/providers/music_provider.dart';

class HomeScreen extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search YouTube...",
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: Colors.purpleAccent),
                    onPressed: () => provider.search(_controller.text),
                  ),
                ),
                onSubmitted: (val) => provider.search(val),
              ),
            ),
            
            Expanded(
              child: provider.isSearching
                  ? Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                  : provider.searchResults.isEmpty
                  ? Center(child: Icon(Icons.search, size: 80, color: Colors.white10))
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: 100),
                      itemCount: provider.searchResults.length,
                      itemBuilder: (context, index) {
                        final song = provider.searchResults[index];
                        final isLoading = provider.loadingSongId == song.id;
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: song.thumbUrl, width: 50, height: 50, fit: BoxFit.cover),
                          ),
                          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white)),
                          subtitle: Text(song.artist, style: TextStyle(color: Colors.white54)),
                          trailing: isLoading 
                            ? CircularProgressIndicator(color: Colors.purpleAccent)
                            : null,
                          onTap: isLoading ? null : () => provider.play(song),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
