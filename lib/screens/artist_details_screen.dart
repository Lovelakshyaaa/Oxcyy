import 'package:flutter/material.dart';
import 'package:oxcy/models/search_models.dart';

class ArtistDetailsScreen extends StatelessWidget {
  final Artist artist;

  const ArtistDetailsScreen({Key? key, required this.artist}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(artist.name),
      ),
      body: Center(
        child: Text('Details for ${artist.name}'),
      ),
    );
  }
}
