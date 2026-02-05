import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/home_screen.dart';
import 'package:oxcy/screens/player_screen.dart'; // Import the new SmartPlayer

void main() {
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
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      home: MainScaffold(), // Use the new wrapper
    );
  }
}

// THE STACK ARCHITECTURE
class MainScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Home Screen (Bottom Layer)
          HomeScreen(),
          
          // 2. The Smart Player (Top Layer - Floating)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SmartPlayer(),
          ),
        ],
      ),
    );
  }
}
