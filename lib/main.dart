import 'dart:async'; // Needed for timeout
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';

// INTERNAL IMPORTS - Change 'oxcy' to your project name if needed
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/home_screen.dart'; // Ensure you have this file
import 'package:oxcy/screens/player_screen.dart'; // Ensure you have this file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // SAFETY CHECK: Try to start audio service, but give up after 3 seconds
  // This prevents the app from freezing on splash screen on some Androids.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 3));
  } catch (e) {
    print("Audio Init Failed or Timed Out: $e");
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OXCY',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0F0C29),
        // Uses Google Fonts for that modern look
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      // This Stack ensures the MiniPlayer is always visible above the Home Screen
      home: MainScaffold(),
    );
  }
}

class MainScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Main Content
          HomeScreen(),
          
          // 2. The Mini Player (Floating at bottom)
          Positioned(
            left: 0, 
            right: 0, 
            bottom: 0,
            // Ensure SmartPlayer exists in your player_screen.dart
            child: SmartPlayer(), 
          ),
        ],
      ),
    );
  }
}
