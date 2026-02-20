import 'package:flutter/material.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/widgets/mini_player.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:oxcy/screens/explore_screen.dart';
import 'package:oxcy/screens/player_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      Provider.of<MusicProvider>(context, listen: false);
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
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
              const PlayerScreen(),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              if (!provider.isPlayerVisible)
              BottomNavigationBar(
                backgroundColor: const Color(0xFF1A1A3D),
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
                  BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Local Music'),
                ],
              ),
            ],
          )
        );
      },
    );
  }
}
