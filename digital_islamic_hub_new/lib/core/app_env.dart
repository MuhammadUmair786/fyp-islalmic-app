import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
      debugPrint('dotenv: loaded .env successfully. AI_API_KEY present: ${dotenv.env['AI_API_KEY'] != null}');
      return;
    } catch (e) {
      debugPrint('dotenv: .env load failed ($e). Trying fallback...');
    }
    try {
      await dotenv.load(fileName: '.env.example');
      _loaded = true;
    } catch (e) {
      debugPrint('dotenv: failed to load environment files ($e). Using fallbacks.');
    }
  }

  static String get(String key, {String fallback = ''}) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static String get aiApiKey => get('AI_API_KEY');

  static String get googleMapsApiKey => get('GOOGLE_MAPS_API_KEY');
}
