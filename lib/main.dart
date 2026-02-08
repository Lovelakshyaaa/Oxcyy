import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart'; 
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/screens/home_screen.dart'; 
import 'package:oxcy/screens/player_screen.dart';
import 'package:oxcy/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        scaffoldBackgroundColor: Colors.transparent, 
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      home: SplashScreen(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    LocalMusicScreen(), 
    HomeScreen(),       
  ];

  @override
  Widget build(BuildContext context) {
    // We access provider to check if player should be visible for padding
    final provider = Provider.of<MusicProvider>(context);
    
    return Scaffold(
      backgroundColor: Color(0xFF0F0C29), 
      body: Stack(
        children: [
          // 1. BACKGROUND
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
          
          // 2. CONTENT
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          
          // 3. PLAYER (The Fix: It sits ABOVE content, BELOW Nav Bar)
          // We use a safe area clamp to ensure it doesn't get hidden
          if (provider.isMiniPlayerVisible)
            Positioned(
              left: 0, 
              right: 0, 
              bottom: provider.isPlayerExpanded ? 0 : 85, // 85 is Nav Bar height
              top: provider.isPlayerExpanded ? 0 : null,
              child: SmartPlayer(),
            ),

          // 4. CRYSTAL GLASS NAV BAR
          if (!provider.isPlayerExpanded) // Hide Nav Bar when player is full screen
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
      borderRadius: 0,
      blur: 10, // LOWER BLUR = CRYSTAL LOOK
      alignment: Alignment.center,
      border: 1, // Slight border for edge definition
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1), // More transparent
          Colors.white.withOpacity(0.05),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.2),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.purpleAccent,
        unselectedItemColor: Colors.white60,
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
