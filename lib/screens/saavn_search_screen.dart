import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/search_provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/artist_details_screen.dart';
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
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
        if (!searchProvider.isFetchingMore && searchProvider.songResults.isNotEmpty) {
          searchProvider.fetchMoreResults();
        }
      }
    });

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

  void _navigateToArtist(Artist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistDetailsScreen(artist: artist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search Songs, Artists & more...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

          final hasSearchResults = provider.topResult != null || provider.songResults.isNotEmpty || provider.artistResults.isNotEmpty;

          if (!hasSearchResults) {
            return _buildPopularSongsList(provider.popularSongs);
          }

          return ListView(
            controller: _scrollController,
            children: [
              if (provider.topResult != null) ...[
                _buildSectionHeader('Top Result'),
                _buildTopResult(provider.topResult!),
              ],
              if (provider.songResults.isNotEmpty) ...[
                _buildSectionHeader('Songs'),
                ...provider.songResults.map((song) => _buildSongItem(song)).toList(),
              ],
              if (provider.isFetchingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (provider.artistResults.isNotEmpty) ...[
                _buildSectionHeader('Artists'),
                _buildArtistList(provider.artistResults),
              ],
               const SizedBox(height: 120), // Padding at the bottom
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTopResult(TopQueryResult result) {
    if (result is Artist) {
      return _buildArtistItem(result, isTopResult: true);
    }
    if (result is Song) {
      return _buildSongItem(result);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSongItem(Song song) {
    return ListTile(
      leading: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: song.thumbUrl,
          width: 56, height: 56, fit: BoxFit.cover,
          imageErrorBuilder: (c,e,s) => const Icon(Icons.music_note, size: 56),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Provider.of<MusicProvider>(context, listen: false).play(song),
    );
  }
  
  Widget _buildArtistList(List<Artist> artists) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: artists.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: _buildArtistItem(artists[index]),
          );
        },
      ),
    );
  }

  Widget _buildArtistItem(Artist artist, {bool isTopResult = false}) {
    return GestureDetector(
      onTap: () => _navigateToArtist(artist),
      child: isTopResult
          ? ListTile(
              leading: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(artist.imageUrl),
                backgroundColor: Colors.transparent,
              ),
              title: Text(artist.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Artist'),
            )
          : SizedBox(
              width: 120,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(artist.imageUrl),
                    backgroundColor: Colors.grey.shade800,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    artist.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPopularSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      children: [
         _buildSectionHeader('Trending Now'),
        ...songs.map((song) => _buildSongItem(song)).toList(),
         const SizedBox(height: 120), // Padding at the bottom
      ],
    );
  }
}
