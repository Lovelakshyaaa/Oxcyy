
# OXCY Music App Blueprint

## Overview

OXCY is a sleek, modern music streaming application for Flutter that acts as an alternative to YouTube Music. It leverages `youtube_explode_dart` to source audio from YouTube videos and `just_audio` for high-quality playback. The app is designed with a dark, immersive UI featuring glassmorphism effects and a clean, iOS-inspired aesthetic.

## Style, Design, and Features

### V1 - Initial Release

*   **Core Architecture:**
    *   **State Management:** `provider` for managing application state, including search results and player status.
    *   **Audio Backend:** `youtube_explode_dart` for searching and extracting audio streams from YouTube, and `just_audio` for background-capable audio playback.
    *   **UI Toolkit:** Flutter with Material Design components.

*   **Design System:**
    *   **Theme:** A dark, sophisticated theme with a gradient background from deep black to purple, creating an immersive listening experience.
    *   **Glassmorphism:** Manually implemented glass effect using `BackdropFilter` for UI elements like search bars and list items, giving the app a modern, layered look without external packages.
    *   **Typography:** `GoogleFonts.poppins` is used throughout the app for a clean, modern, and readable text style.
    *   **Imagery:** `cached_network_image` is used for efficiently loading and caching album art, ensuring a smooth and responsive UI.

*   **Key Features:**
    *   **Home Screen:**
        *   A prominent, glass-style search bar at the top for discovering music.
        *   A dynamic list of search results, each displayed in a glass-style card showing the track's thumbnail, title, and artist.
        *   A loading indicator while searches are in progress.
    *   **Player Screen:**
        *   A full-screen, immersive player experience.
        *   The background is a beautifully blurred version of the current track's album art.
        *   A large, high-quality centered album art as the focal point.
        *   Sleek, intuitive player controls (Play/Pause) and a song progress slider.
    *   **Navigation:** Tapping a song in the search results seamlessly navigates to the full-screen player and begins playback.

## Current Plan: Initial Build

This is the initial creation of the application. The plan is to build all the core features described above.

*   **Step 1: Project Setup:**
    *   Remove the unused `glassmorphism` package from `pubspec.yaml` to adhere to the manual implementation requirement.
    *   Create the necessary file structure: `lib/providers/`, `lib/screens/`.

*   **Step 2: Create `main.dart`:**
    *   Set up the main application entry point.
    *   Implement the dark theme with the specified gradient and `GoogleFonts.poppins`.
    *   Configure `ChangeNotifierProvider` to make the `MusicProvider` available throughout the widget tree.

*   **Step 3: Create `providers/music_provider.dart`:**
    *   Develop the `MusicProvider` class to handle all business logic.
    *   Integrate `youtube_explode_dart` for searching videos.
    *   Integrate `just_audio` for managing audio playback (play, pause, seek).
    *   Manage and expose all necessary states: search results, loading status, and player state (playing, position, duration).

*   **Step 4: Create `screens/home_screen.dart`:**
    *   Build the home screen UI.
    *   Implement the custom glassmorphism search bar.
    *   Create the list view to display search results from `MusicProvider`.
    *   Implement the navigation logic to the `PlayerScreen`.

*   **Step 5: Create `screens/player_screen.dart`:**
    *   Build the full-screen player UI.
    *   Implement the blurred album art background effect.
    *   Add the main album art, track information, and player controls (play/pause button and progress slider) linked to the `MusicProvider`.

*   **Step 6: Finalize & Verify:**
    *   Run `flutter pub get` to sync dependencies.
    *   Ensure the application is free of analysis errors and runs correctly.
