import 'package:flutter/material.dart';
import 'package:oxcy/screens/album_details_screen.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/screens/playlist_details_screen.dart';
import 'package:oxcy/screens/search_screen_delegate.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:oxcy/screens/explore_screen.dart';
import 'package:oxcy/screens/player_screen.dart';
import 'package:oxcy/widgets/mini_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => MusicData()),
      ],
      child: MaterialApp(
        title: 'OXY',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F0C29),
          primaryColor: const Color(0xFF24243E),
          colorScheme: const ColorScheme.dark().copyWith(
            primary: const Color(0xFFA248E2),
            secondary: const Color(0xFF24243E),
            surface: const Color(0xFF161334),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [const ExploreScreen(), const LocalMusicScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MusicProvider>(context, listen: false).fetchLocalMusic();
    });
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
        if (provider.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showErrorSnackBar(provider.errorMessage!); 
            provider.clearError();
          });
        }

        return WillPopScope(
          onWillPop: () async {
            if (provider.isPlayerExpanded) {
              provider.collapsePlayer();
              return false; 
            }
            return true; 
          },
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
                if (provider.currentSong != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    bottom: provider.isPlayerExpanded ? 0 : 85,
                    top: provider.isPlayerExpanded ? 0 : null,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (!provider.isPlayerExpanded) {
                          if (details.primaryVelocity! < -1500) { 
                            provider.togglePlayerView();
                          }
                        } else {
                          if (details.primaryVelocity! > 1500) { 
                            provider.togglePlayerView();
                          }
                        }
                      },
                      child: const PlayerScreen(),
                    ),
                  ),
                if (provider.currentSong != null && !provider.isPlayerExpanded)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: MiniPlayer(),
                  ),
              ],
            ),
            bottomNavigationBar: provider.isPlayerExpanded
                ? null
                : BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) => setState(() => _currentIndex = index),
                    items: const [
                      BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
                      BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Local Music'),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
