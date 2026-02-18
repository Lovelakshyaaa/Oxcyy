import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:audio_service/audio_service.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/screens/explore_screen.dart';
import 'package:oxcy/screens/player_screen.dart';
import 'package:oxcy/screens/splash_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MusicProvider()),
        ChangeNotifierProvider(create: (context) => MusicData()),
      ],
      child: const MyApp(),
    ),
  );
}

class BouncingScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: BouncingScrollBehavior(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'OXCY',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  _MainScaffoldState createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const LocalMusicScreen(),
    const ExploreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Provider.of<MusicProvider>(context, listen: false).fetchLocalMusic();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
        if (provider.errorMessage != null) {
          Fluttertoast.showToast(
            msg: provider.errorMessage!,
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          provider.clearError();
        }

        final audioHandler = provider.audioHandler;

        return WillPopScope(
          onWillPop: () async {
            if (provider.isPlayerExpanded) {
              provider.collapsePlayer();
              return false;
            }
            return true;
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F0C29),
            body: Stack(
              children: [
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
                IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
                if (audioHandler != null)
                  StreamBuilder<MediaItem?>(
                    stream: audioHandler.mediaItem,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.fastOutSlowIn,
                        left: 0,
                        right: 0,
                        bottom: provider.isPlayerExpanded ? 0 : 85,
                        top: provider.isPlayerExpanded ? 0 : null,
                        child: const SmartPlayer(),
                      );
                    },
                  ),
                if (!provider.isPlayerExpanded)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildGlassNavBar(),
                  ),
              ],
            ),
          ),
        );
      },
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
            icon: Icon(Icons.explore_rounded),
            label: "Explore",
          ),
        ],
      ),
    );
  }
}
