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

## Current Task: Fix `just_audio` Breaking Changes

In this session, I have resolved breaking changes caused by an update to the `just_audio` package. The key changes include:

- **Removed `just_audio_background`**: Removed the deprecated `just_audio_background` package and its initialization in `lib/main.dart`.
- **Updated `music_provider.dart`**: Replaced the `MediaItem` class with `AudioSource` from the `just_audio` package and updated the `getLocalSongsByAlbum` method.
- **Fixed `artist_details_screen.dart`**: Removed a reference to the non-existent `year` property in the `Album` model.
