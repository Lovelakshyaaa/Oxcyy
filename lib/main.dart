import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart'; 
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/screens/home_screen.dart'; 
import 'package:oxcy/screens/player_screen.dart';
import 'package:oxcy/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final musicProvider = MusicProvider();
  await musicProvider.init();

  final audioHandler = musicProvider.audioHandler;

  if (audioHandler == null) {
    print("CRITICAL: AudioHandler failed to initialize!");
  }

  runApp(
    MultiProvider(
      providers: [
        if (audioHandler != null)
          Provider<AudioHandler>.value(value: audioHandler),
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
    final AudioHandler? handler = Provider.of<AudioHandler?>(context);
    final provider = Provider.of<MusicProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29), 
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
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
          
          // Main content pages (My Music / Search)
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          
          // Player – shown only when a song is playing
          if (handler != null)
            StreamBuilder<MediaItem?>(
              stream: handler.mediaItem,
              builder: (context, snapshot) {
                final bool showPlayer = snapshot.hasData || provider.isMiniPlayerVisible;
                if (!showPlayer) return const SizedBox.shrink();

                return Positioned(
                  left: 0, 
                  right: 0, 
                  bottom: provider.isPlayerExpanded ? 0 : 85,
                  top: provider.isPlayerExpanded ? 0 : null,
                  // 🔥 KEY FIX: Force rebuild when media item changes (prevents flicker)
                  child: SmartPlayer(key: ValueKey(snapshot.data?.id)),
                );
              }
            ),

          // Glass navigation bar (hidden when player expanded)
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
        items: const [
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
