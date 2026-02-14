# Oxcy Music Player Blueprint

## Overview

A modern, glassmorphism-style music player for Android designed to provide a visually stunning and fluid user experience for playing local audio files. The app automatically scans for and displays local music albums, featuring a full-screen player, a mini-player, and professional, seamless animations for all navigation and player transitions.

## Style, Design, and Features

### Styling & Design

*   **Theme:** A sleek dark theme with a dynamic gradient background, transitioning from deep blue to dark purple (`#0F0C29` -> `#302B63` -> `#24243E`).
*   **Typography:** Utilizes `GoogleFonts.poppins` for all text, ensuring a modern, clean, and highly readable interface.
*   **Glassmorphism:** Key UI elements, such as the bottom navigation bar and album art containers, use a frosted-glass effect to create a sense of depth and style.
*   **Animations:**
    *   **Staggered Lists:** A cascading slide-and-fade animation is applied to the album grid and song lists as they load, creating a professional and engaging effect.
    *   **Screen Navigation:** Employs `SharedAxisTransition` for smooth, horizontal slide-and-fade animations between screens.
    *   **Player Transitions:** Uses `AnimatedPositioned` to create a fluid, graceful animation when expanding and collapsing the music player.
*   **Scrolling:** Implements a custom "bouncing" (elastic) scroll behavior for a more dynamic and engaging feel when browsing lists.
*   **Iconography:** Features a custom launcher icon for a unique brand identity.
*   **Image Quality:** All album and track artwork is rendered in the high-quality **PNG** format. This is achieved by using the `getArtwork` method from the `MusicProvider`, which fetches the lossless artwork data directly.

### Core Features

*   **Automatic Music Discovery:** The app automatically and silently scans the device for local music albums on every startup, ensuring the library is always up-to-date without any user intervention.
*   **Album & Song Display:**
    *   Displays a grid of local music albums on the main screen.
    *   Tapping an album navigates to a detailed view listing all its songs.
*   **Background Audio Playback:**
    *   Leverages the `audio_service` package to manage background audio playback, allowing music to continue playing when the app is minimized.
    *   Uses `provider` with a `MusicProvider` class to manage all application state, including the currently playing song, playback status, and player UI (expanded/collapsed).
*   **Interactive Player:**
    *   **Smart Player UI (`SmartPlayer`):** A feature-rich player interface that can be viewed in both a full-screen (expanded) and a mini-player (collapsed) state.
    *   Includes all standard playback controls: play/pause, skip to next/previous, and a draggable seek bar.
*   **Intuitive Navigation:**
    *   A glassmorphic bottom navigation bar allows users to switch between the "My Music" and "Search" screens.
    *   `SharedAxisPageRoute` ensures all screen transitions are consistent and animated.
    *   **Intelligent Back Button:** `WillPopScope` is implemented to provide a superior user experience. Pressing the back button will first collapse the expanded player before exiting the app, preventing accidental closure.

## Current Change: Restore High-Quality Artwork

This section documents the correction of a previous fix to ensure high-quality artwork is displayed without causing build errors.

*   **Goal:** To restore the display of high-quality, lossless PNG artwork for all album and track images.
*   **Problem:** The `QueryArtworkWidget` from the `on_audio_query` package does not support specifying the artwork format directly, which led to a build error when attempted.
*   **Solution:**
    1.  **Replaced `QueryArtworkWidget`:** In `lib/screens/local_music_screen.dart` and `lib/screens/album_songs_screen.dart`, the `QueryArtworkWidget` was replaced with a `FutureBuilder`.
    2.  **Used `MusicProvider.getArtwork`:** The `FutureBuilder` now calls the `getArtwork` method from the `MusicProvider`, which correctly fetches the high-quality PNG artwork data.
    3.  **Displayed with `Image.memory`:** The returned image data is now displayed using the `Image.memory` widget.
*   **Result:** The app now correctly displays high-quality PNG artwork for all images, as originally intended, and the previous build error is resolved.
