import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/search_provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:transparent_image/transparent_image.dart';

class SaavnSearchScreen extends StatefulWidget {
  const SaavnSearchScreen({super.key});

  @override
  State<SaavnSearchScreen> createState() => _SaavnSearchScreenState();
}

class _SaavnSearchScreenState extends State<SaavnSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Use a variable for the provider to avoid repeated lookups
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);

    _scrollController.addListener(() {
      // Check if we are at the bottom of the list
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        // And if we are not already fetching more results
        if (!searchProvider.isFetchingMore && searchProvider.searchResults.isNotEmpty) {
          searchProvider.fetchMoreResults();
        }
      }
    });

    // Clear any previous search when the screen is entered
    searchProvider.clearSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Provider.of<SearchProvider>(context, listen: false).search(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search for songs on JioSaavn...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _performSearch,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              Provider.of<SearchProvider>(context, listen: false).clearSearch();
            },
          )
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, provider, child) {
          if (provider.isSearching) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Text(provider.errorMessage!),
            );
          }

          // If there are search results, show them. Otherwise, show popular songs.
          final List<Song> songsToShow = provider.searchResults.isNotEmpty 
              ? provider.searchResults 
              : provider.popularSongs;
          
          String listTitle = provider.searchResults.isNotEmpty 
              ? 'Search Results' 
              : 'Trending Now';

          if (provider.isFetchingPopular && songsToShow.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  listTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: songsToShow.length + (provider.isFetchingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == songsToShow.length) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final song = songsToShow[index];
                    return ListTile(
                      leading: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FadeInImage.memoryNetwork(
                          placeholder: kTransparentImage,
                          image: song.thumbUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          imageErrorBuilder: (context, error, stack) => 
                            const Icon(Icons.music_note, size: 50), 
                        ),
                      ),
                      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        // Use the MusicProvider to play the song
                        Provider.of<MusicProvider>(context, listen: false).play(song);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
