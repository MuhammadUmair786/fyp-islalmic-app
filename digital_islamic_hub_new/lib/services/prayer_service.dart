import 'package:flutter/foundation.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerService {
  /// Returns cached times instantly if available, otherwise calculates for default location
  static Future<PrayerTimes> getQuickPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double lat = prefs.getDouble('last_lat') ?? 24.8607;
      double lng = prefs.getDouble('last_lng') ?? 67.0011;
      return _calculateTimes(lat, lng);
    } catch (e) {
      debugPrint('Quick prayer times error: $e');
      return _calculateTimes(24.8607, 67.0011);
    }
  }

  static Future<PrayerTimes?> getPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Try to get real location in background
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position? position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          await prefs.setDouble('last_lat', position.latitude);
          await prefs.setDouble('last_lng', position.longitude);
          return _calculateTimes(position.latitude, position.longitude);
        }
      }

      // 2. Return whatever is in cache (Karachi default if empty)
      return getQuickPrayerTimes();
    } catch (e) {
      debugPrint("Prayer Service Error: $e");
      return getQuickPrayerTimes();
    }
  }

  static PrayerTimes _calculateTimes(double lat, double lng) {
    final coordinates = Coordinates(lat, lng);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    return PrayerTimes.today(coordinates, params);
  }
}
