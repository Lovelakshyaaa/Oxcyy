import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/album_details_screen.dart';
import 'package:oxcy/screens/artist_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

// Integrates with Flutter's SearchDelegate to provide a rich search experience.
class SearchScreenDelegate extends SearchDelegate<SearchResult?> {
  // Defines the theme for the search app bar.
  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(color: theme.primaryColorLight, fontSize: 18),
      ),
    );
  }

  // Defines the actions for the app bar (e.g., a 'clear' button).
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  // Defines the leading icon/button in the app bar (e.g., a 'back' button).
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  // This method is called when the user submits a search query.
  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return _buildSuggestionsWidget(context);
    }

    return FutureBuilder<Map<String, List<SearchResult>>>(
      future: Provider.of<MusicProvider>(context, listen: false).search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData ||
            (snapshot.data!['songs']!.isEmpty &&
                snapshot.data!['albums']!.isEmpty &&
                snapshot.data!['artists']!.isEmpty)) {
          return const Center(child: Text('No results found.'));
        }

        final results = snapshot.data!;
        final songs = results['songs'] ?? [];
        final albums = results['albums'] ?? [];
        final artists = results['artists'] ?? [];

        return _buildSearchResults(context, songs, albums, artists);
      },
    );
  }

  // This method provides suggestions as the user types.
  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestionsWidget(context);
  }

  Widget _buildSuggestionsWidget(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 48),
            SizedBox(height: 16),
            Text('Search for songs, artists, and albums...'),
          ],
        ),
      ),
    );
  }

  // Builds the final list of search results.
  Widget _buildSearchResults(BuildContext context, List<SearchResult> songs,
      List<SearchResult> albums, List<SearchResult> artists) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        children: [
          if (songs.isNotEmpty)
            _buildSection(context, 'Songs', songs, _buildSongItem),
          if (albums.isNotEmpty)
            _buildSection(context, 'Albums', albums, _buildAlbumItem),
          if (artists.isNotEmpty)
            _buildSection(context, 'Artists', artists, _buildArtistItem),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context,
      String title,
      List<SearchResult> items,
      Widget Function(BuildContext, SearchResult) builder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...items.map((item) => builder(context, item)),
      ],
    );
  }

  // --- WIDGET BUILDERS FOR DIFFERENT SEARCH RESULT TYPES ---

  Widget _buildSongItem(BuildContext context, SearchResult item) {
    final song = item as Song;
    return ListTile(
      leading: Card(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: song.highQualityImageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          imageErrorBuilder: (context, error, stack) =>
              const Icon(Icons.music_note, size: 50),
        ),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle:
          Text(song.artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Provider.of<MusicProvider>(context, listen: false).play(song),
    );
  }

  Widget _buildArtistItem(BuildContext context, SearchResult item) {
    final artist = item as Artist;
    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: NetworkImage(artist.highQualityImageUrl),
        onBackgroundImageError: (e, s) => {},
        child: artist.highQualityImageUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ArtistDetailsScreen(artistId: artist.id)),
        );
      },
    );
  }

  Widget _buildAlbumItem(BuildContext context, SearchResult item) {
    final album = item as Album;
    return ListTile(
      leading: Card(
        elevation: 2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: album.highQualityImageUrl,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          imageErrorBuilder: (context, error, stack) =>
              const Icon(Icons.album, size: 50),
        ),
      ),
      title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle:
          Text(album.artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => AlbumDetailsScreen(albumId: album.id)),
        );
      },
    );
  }
}
