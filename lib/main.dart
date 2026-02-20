
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:oxcy/providers/music_data_provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/explore_screen.dart';
import 'package:oxcy/screens/local_music_screen.dart';
import 'package:oxcy/screens/player_screen.dart';
import 'package:oxcy/services/audio_handler.dart';
import 'package:oxcy/widgets/mini_player.dart';
import 'package:provider/provider.dart';

late AudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  void _requestPermission() async {
    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      await _audioQuery.permissionsRequest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider(_audioHandler)),
        ChangeNotifierProvider(create: (_) => MusicData()),
        Provider<AudioHandler>.value(value: _audioHandler),
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
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
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
                      BottomNavigationBarItem(
                          icon: Icon(Icons.explore), label: 'Explore'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.music_note), label: 'Local Music'),
                    ],
                  ),
              ],
            ));
      },
    );
  }
}
