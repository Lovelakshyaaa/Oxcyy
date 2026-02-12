import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart'; 
import 'package:audio_service/audio_service.dart'; // ⚠️ REQUIRED
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/screens/home_screen.dart'; 
import 'package:oxcy/screens/player_screen.dart';
import 'package:oxcy/screens/splash_screen.dart';

// ⚠️ MAKE MAIN ASYNC TO AWAIT INITIALIZATION
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. BOOTSTRAP: Initialize the Provider & Audio Service BEFORE the UI boots
  final musicProvider = MusicProvider();
  await musicProvider.init(); // This calls initAudioService() internally

  // 2. EXTRACTION: Get the now-alive AudioHandler
  final audioHandler = musicProvider.audioHandler;

  if (audioHandler == null) {
    print("CRITICAL: AudioHandler failed to initialize!");
  }

  runApp(
    MultiProvider(
      providers: [
        // 3. PROVIDE AUDIO HANDLER GLOBALLY (The Firebase Recommendation)
        if (audioHandler != null)
          Provider<AudioHandler>.value(value: audioHandler),
        
        // 4. PROVIDE THE INITIALIZED MUSIC PROVIDER
        ChangeNotifierProvider<MusicProvider>.value(value: musicProvider),
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
    // We try to get the AudioHandler to listen for REAL-TIME updates
    final AudioHandler? handler = Provider.of<AudioHandler?>(context);
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
          
          // 3. PLAYER (The Fix: Reactive Visibility)
          // We use StreamBuilder to show the player INSTANTLY when a song loads
          if (handler != null)
            StreamBuilder<MediaItem?>(
              stream: handler.mediaItem,
              builder: (context, snapshot) {
                // Show player if MediaItem exists OR if Provider thinks it should show
                final bool showPlayer = snapshot.hasData || provider.isMiniPlayerVisible;
                
                if (!showPlayer) return SizedBox.shrink();

                return Positioned(
                  left: 0, 
                  right: 0, 
                  bottom: provider.isPlayerExpanded ? 0 : 85,
                  top: provider.isPlayerExpanded ? 0 : null,
                  // *** THE FIX IS HERE ***
                  // The audioHandler parameter has been removed.
                  child: SmartPlayer(),
                );
              }
            ),

          // 4. CRYSTAL GLASS NAV BAR
          if (!provider.isPlayerExpanded) 
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
      blur: 10,
      alignment: Alignment.center,
      border: 1, 
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.1), 
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
