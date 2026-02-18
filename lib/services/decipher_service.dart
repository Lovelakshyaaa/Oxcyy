import 'dart:convert'; // Import the dart:convert library
import 'package:flutter/services.dart';
import 'package:flutter_js/flutter_js.dart';

// This service manages the JavaScript engine for deciphering YouTube signatures.
class DecipherService {
  late final JavascriptRuntime _jsRuntime;
  bool _isInitialized = false;

  DecipherService() {
    _jsRuntime = getJavascriptRuntime();
  }

  // Initializes the JavaScript runtime by loading all necessary solver scripts.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Load all the required JS libraries from the assets.
      final polyfill = await rootBundle.loadString('knowledge/polyfill.js');
      final astring =
          await rootBundle.loadString('knowledge/astring-1.9.0.min.js');
      final meriyah =
          await rootBundle.loadString('knowledge/meriyah-6.1.4.min.js');
      final solver = await rootBundle.loadString('knowledge/yt.solver.core.js');

      _jsRuntime.evaluate(polyfill);
      _jsRuntime.evaluate(astring);
      _jsRuntime.evaluate(meriyah);
      _jsRuntime.evaluate(solver);

      _isInitialized = true;
      print("Decipher Service Initialized Successfully.");
    } catch (e) {
      print("Failed to initialize Decipher Service: $e");
    }
  }

  // Calls the JavaScript function to decipher the signature.
  Future<String> decipher(String signature) async {
    if (!_isInitialized) {
      await init(); // Ensure initialization if called prematurely
      if (!_isInitialized) {
        throw Exception("Decipher service could not be initialized");
      }
    }

    try {
      // *** THE CRITICAL FIX ***
      // Use jsonEncode to safely pass the string to the JavaScript context.
      // This prevents syntax errors if the signature contains special characters.
      final result = _jsRuntime.evaluate('solveN(${jsonEncode(signature)})');
      return result.stringResult;
    } catch (e) {
      print("Failed to decipher signature: $e");
      return ''; // Return empty string on failure
    }
  }

  void dispose() {
    _jsRuntime.dispose();
  }
}
