import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/album_details_screen.dart';
import 'package:oxcy/screens/artist_details_screen.dart';
import 'package:oxcy/screens/playlist_details_screen.dart';
import 'package:provider/provider.dart';
import 'package:transparent_image/transparent_image.dart';

// Integrates with Flutter's SearchDelegate to provide a rich search experience.
class SearchScreenDelegate extends SearchDelegate<SearchResult> {
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
          // Also clear the results in the provider when the query is cleared.
          Provider.of<MusicData>(context, listen: false).clearSearch();
        },
      ),
    ];
  }

  // Defines the leading icon/button in the app bar (e.g., a 'back' button).
  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, {} as SearchResult),
    );
  }

  // This method is called when the user submits a search query.
  @override
  Widget buildResults(BuildContext context) {
    // Trigger the search in the MusicDataProvider.
    Provider.of<MusicData>(context, listen: false).search(query);

    // Use a Consumer to listen for changes in the MusicData provider.
    return Consumer<MusicData>(
      builder: (context, data, child) {
        if (data.isSearching) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.errorMessage != null) {
          return Center(child: Text(data.errorMessage!));
        }
        // Build the list of search results.
        return _buildSearchResults(context, data.searchResults);
      },
    );
  }

  // This method provides suggestions as the user types.
  @override
  Widget buildSuggestions(BuildContext context) {
    // Suggestions are not implemented; the user must submit the search.
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
  Widget _buildSearchResults(BuildContext context, List<SearchResult> results) {
    if (results.isEmpty) {
      return const Center(child: Text('No results found.'));
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final item = results[index];
          // Determine the type of the search result and build the appropriate ListTile.
          if (item is Song) {
            return _buildSongItem(context, item);
          } else if (item is Artist) {
            return _buildArtistItem(context, item);
          } else if (item is Album) {
            return _buildAlbumItem(context, item);
          } else if (item is Playlist) {
            return _buildPlaylistItem(context, item);
          }
          return const SizedBox.shrink(); // Return an empty widget for unknown types.
        },
      ),
    );
  }

  // --- WIDGET BUILDERS FOR DIFFERENT SEARCH RESULT TYPES ---

  Widget _buildSongItem(BuildContext context, Song song) {
    return ListTile(
      leading: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: song.highQualityImageUrl,
          width: 50, height: 50, fit: BoxFit.cover,
        ),
      ),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song.artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Provider.of<MusicProvider>(context, listen: false).play(song),
    );
  }

  Widget _buildArtistItem(BuildContext context, Artist artist) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(artist.highQualityImageUrl),
      ),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ArtistDetailsScreen(artistId: artist.id)),
        );
      },
    );
  }

  Widget _buildAlbumItem(BuildContext context, Album album) {
    return ListTile(
      leading: Card(
         elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: album.highQualityImageUrl,
          width: 50, height: 50, fit: BoxFit.cover,
        ),
      ),
      title: Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(album.artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AlbumDetailsScreen(albumId: album.id)),
        );
      },
    );
  }

  Widget _buildPlaylistItem(BuildContext context, Playlist playlist) {
    return ListTile(
      leading: Card(
         elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        clipBehavior: Clip.antiAlias,
        child: FadeInImage.memoryNetwork(
          placeholder: kTransparentImage,
          image: playlist.highQualityImageUrl,
          width: 50, height: 50, fit: BoxFit.cover,
        ),
      ),
      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PlaylistDetailsScreen(playlistId: playlist.id)),
        );
      },
    );
  }
}
