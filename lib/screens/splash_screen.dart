import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/main.dart'; 

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<void> _initApp() async {
    final provider = Provider.of<MusicProvider>(context, listen: false);
    
    // 1. Initialize Engine
    await provider.init();
    
    // 2. Force a delay so the splash looks nice (Fixes "Half Second" glitch)
    await Future.delayed(Duration(seconds: 2));
    
    // 3. Navigate
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0C29),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded, size: 100, color: Colors.purpleAccent),
            SizedBox(height: 20),
            Text(
              "OXCY", 
              style: TextStyle(
                color: Colors.white, 
                fontSize: 32, 
                fontWeight: FontWeight.bold,
                letterSpacing: 2
              )
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.purpleAccent),
            SizedBox(height: 20),
            Text("Starting Engine...", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
