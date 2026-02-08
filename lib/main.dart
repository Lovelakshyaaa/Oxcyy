import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart'; // The Glass Effect
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/screens/home_screen.dart'; // The Search Screen
import 'package:oxcy/screens/player_screen.dart'; // The Player

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize the Engine
  final musicProvider = MusicProvider();
  await musicProvider.init(); 

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: musicProvider),
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
        scaffoldBackgroundColor: Colors.transparent, // Important for glass
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
  int _currentIndex = 0;
  
  // The two main screens
  final List<Widget> _pages = [
    LocalMusicScreen(), // Index 0: My Music
    HomeScreen(),       // Index 1: Search
  ];

  @override
  Widget build(BuildContext context) {
    // We use a Stack to layer the Background -> Content -> Player -> Glass Nav
    return Scaffold(
      backgroundColor: Color(0xFF0F0C29), // Deep base color
      body: Stack(
        children: [
          // 1. THE AMBIENT BACKGROUND
          // A rich gradient that makes the glass effect pop
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0C29), 
                  Color(0xFF302B63), 
                  Color(0xFF24243E)
                ],
              ),
            ),
          ),
          
          // 2. THE PAGE CONTENT
          // IndexedStack keeps the state of both pages alive
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          
          // 3. THE SMART PLAYER (Miniplayer)
          // Sits above the Nav Bar
          Positioned(
            left: 0, right: 0, 
            bottom: 85, // Push it up so it doesn't hide behind the Nav Bar
            child: SmartPlayer(),
          ),

          // 4. THE GLASS NAVIGATION BAR
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildGlassNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 85,
      borderRadius: 0, // Flat bottom
      blur: 20,
      alignment: Alignment.center,
      border: 0,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFffffff).withOpacity(0.1),
          Color(0xFFFFFFFF).withOpacity(0.05),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFffffff).withOpacity(0.5),
          Color((0xFFFFFFFF)).withOpacity(0.5),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent, // Let the glass show through
        elevation: 0,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_rounded),
            label: "My Music",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: "Search",
          ),
        ],
      ),
    );
  }
}
