# Blueprint: OXCY Music Player

## Overview

OXCY is a sleek, modern music player for Android that seamlessly integrates local music playback with online streaming from YouTube. It features a beautiful, glassmorphism-inspired interface with smooth animations and a focus on high-quality album art.

## Features & Design

### Core Functionality
*   **Local & YouTube Playback:** Plays audio files from the user's device and streams audio from YouTube.
*   **Search:** Users can search for music on YouTube.
*   **Audio Handler:** Uses `audio_service` and `just_audio` for robust background audio playback, notification controls, and queue management.
*   **State Management:** Uses `provider` to manage application state, including player status, search results, and local music library.

### User Interface & Experience
*   **Glassmorphism UI:** A beautiful, multi-layered "glass" effect is used for the navigation bar, creating a sense of depth and style.
*   **Gradient Background:** A subtle, animated gradient provides a visually pleasing backdrop for the entire app.
*   **Smooth Navigation:** Page transitions use a gentle fade effect, and scrolling has a natural, elastic feel for a polished user experience.
*   **High-Quality Artwork:** The app is optimized to display album art in its original, highest possible quality, ensuring a visually rich experience.
*   **Splash Screen:** A simple splash screen provides a professional entry point to the app.

### Music Library & Player
*   **Local Music Discovery:** Automatically scans the device for local audio files and organizes them by album.
*   **Album & Song Views:** Users can browse their local music library by album and view the songs within each album.
*   **Player Screen:** A dedicated player screen shows the currently playing track, artist, and high-resolution album art.
*   **Playback Controls:** Standard playback controls (play/pause, next, previous, seek) are available.
*   **Repeat & Shuffle:** The player supports repeating the current track or the entire queue, as well as shuffling the playlist.

## Current Task: Final Touches & Polish

The following changes have been implemented to complete the application:

*   **Original Quality Artwork:** The app now fetches and displays album art in its original, highest possible quality.
*   **Functional Loop Button:** The loop button in the player now correctly cycles through repeat modes (none, one, all).
*   **Smooth Navigation:** Page transitions now use a fade effect for a more seamless experience.
*   **Elastic Scrolling:** Scrolling physics have been adjusted to provide a more natural, "bouncing" feel.
*   **Bug Fixes:** Several build errors related to sorting and type safety have been resolved.

This completes the development of the OXCY Music Player. The app is now fully functional, visually polished, and ready for use.