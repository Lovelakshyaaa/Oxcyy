import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/home_screen.dart'; // This is your Search Screen
import 'package:oxcy/screens/local_music_screen.dart'; // The New Local Screen
import 'package:oxcy/screens/player_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.oxcy.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (e) { print(e); }
  
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => MusicProvider())],
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
      home: MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;
  
  // The two screens
  final List<Widget> _pages = [
    LocalMusicScreen(), // Index 0: Local
    HomeScreen(),       // Index 1: Search (Your old screen)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient for the whole app
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
              ),
            ),
          ),
          
          // The Active Screen
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          
          // The Mini Player (Always on top)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SmartPlayer(),
          ),
        ],
      ),
      
      // The Tab Bar
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A2E).withOpacity(0.9),
          indicatorColor: Colors.purpleAccent.withOpacity(0.2),
          labelTextStyle: MaterialStateProperty.all(GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
        ),
        child: NavigationBar(
          height: 65,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.library_music, color: Colors.purpleAccent),
              label: 'My Music',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined, color: Colors.white54),
              selectedIcon: Icon(Icons.search, color: Colors.purpleAccent),
              label: 'Search',
            ),
          ],
        ),
      ),
    );
  }
}
