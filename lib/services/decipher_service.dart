
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
      final astring = await rootBundle.loadString('knowledge/astring-1.9.0.min.js');
      final meriyah = await rootBundle.loadString('knowledge/meriyah-6.1.4.min.js');
      final solver = await rootBundle.loadString('knowledge/yt.solver.core.js');

      // Evaluate the scripts in the JS runtime.
      _jsRuntime.evaluate(polyfill);
      _jsRuntime.evaluate(astring);
      _jsRuntime.evaluate(meriyah);
      _jsRuntime.evaluate(solver);

      _isInitialized = true;
      print("Decipher Service Initialized Successfully.");
    } catch (e) {
      print("Failed to initialize Decipher Service: $e");
      // You might want to handle this error more gracefully
    }
  }

  // Calls the JavaScript function to decipher the signature.
  // The function name 'solveN' is assumed based on common YouTube solver scripts.
  Future<String> decipher(String signature) async {
    if (!_isInitialized) {
      throw Exception("Decipher service not initialized");
    }

    try {
      // The function to call in JS is `solveN`. We pass the signature to it.
      final result = _jsRuntime.evaluate('solveN("$signature")');
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

