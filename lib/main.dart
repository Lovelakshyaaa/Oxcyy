import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/screens/local_music_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // REMOVED: JustAudioBackground.init() 
  // We are running raw now.
  
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
      home: LocalMusicScreen(), // Force load Local Screen first
    );
  }
}
