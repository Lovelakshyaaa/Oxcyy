This document outlines the project structure, features, and design of the Oxcy Music App.

## Overview

Oxcy is a music streaming application that allows users to search for and play music, browse top charts, and play local music files.

## Features

- **Search**: Users can search for songs, artists, and albums.
- **Music Player**: A full-screen music player with play, pause, seek, shuffle, and repeat functionality.
- **Local Music**: The app can play music files stored on the user's device.
- **Top Charts**: The app displays top charts for songs and albums.
- **Artist and Album Details**: Users can view details for artists and albums, including top songs and albums.
- **Shimmer Effect**: A shimmer effect is displayed while data is loading.

## Design

The app uses a dark theme with a color palette based on deep purple and dark blue. The UI is designed to be modern and intuitive, with a focus on visual appeal and ease of use.

## Current Task: Refactor and Fix Code

In this session, I have refactored the code to fix breaking changes introduced by a previous developer. The main changes include:

- Restoring deleted code in `lib/models/search_models.dart`.
- Updating `lib/providers/music_data_provider.dart` to use `Song.fromJson` instead of a custom parsing logic.
- Restoring missing properties and methods in `lib/providers/music_provider.dart`.
- Fixing errors in `lib/screens/album_details_screen.dart`, `lib/screens/album_songs_screen.dart`, `lib/screens/artist_details_screen.dart`, `lib/screens/explore_screen.dart`, `lib/screens/player_screen.dart`, `lib/screens/playlist_details_screen.dart`, and `lib/screens/search_screen_delegate.dart` caused by the refactoring.
