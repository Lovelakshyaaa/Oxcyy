import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oxcy/providers/music_provider.dart';
import 'package:oxcy/main.dart'; // To access MainScaffold

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start initialization after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<void> _initApp() async {
    final provider = Provider.of<MusicProvider>(context, listen: false);
    await provider.init();
    
    // Navigate to Main App
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0C29),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your App Logo or Icon
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
            Text("Initializing Engine...", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
