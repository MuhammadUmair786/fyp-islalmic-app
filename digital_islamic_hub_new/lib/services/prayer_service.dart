import 'package:flutter/foundation.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerService {
  /// Reactive notifier that holds the current valid prayer times for the whole app.
  static final ValueNotifier<PrayerTimes?> prayerTimesNotifier = ValueNotifier(null);

  /// Returns cached times instantly if available, otherwise calculates for default location (Karachi).
  static Future<PrayerTimes> getQuickPrayerTimes() async {
    if (prayerTimesNotifier.value != null) return prayerTimesNotifier.value!;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      double lat = prefs.getDouble('last_lat') ?? 24.8607;
      double lng = prefs.getDouble('last_lng') ?? 67.0011;
      final pt = _calculateTimes(lat, lng);
      prayerTimesNotifier.value = pt;
      return pt;
    } catch (e) {
      debugPrint('Quick prayer times error: $e');
      final fallback = _calculateTimes(24.8607, 67.0011);
      prayerTimesNotifier.value = fallback;
      return fallback;
    }
  }

  /// Forces a refresh using the best available location.
  static Future<PrayerTimes?> getPrayerTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Try to get real location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position? position = await Geolocator.getLastKnownPosition();
        // If last known is too old or null, try current position briefly
        position ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3),
        ).catchError((_) => null);

        if (position != null) {
          await prefs.setDouble('last_lat', position.latitude);
          await prefs.setDouble('last_lng', position.longitude);
          final pt = _calculateTimes(position.latitude, position.longitude);
          prayerTimesNotifier.value = pt;
          return pt;
        }
      }

      // 2. Return whatever is in cache/notifier
      return await getQuickPrayerTimes();
    } catch (e) {
      debugPrint("Prayer Service Error: $e");
      return await getQuickPrayerTimes();
    }
  }

  static PrayerTimes _calculateTimes(double lat, double lng) {
    final coordinates = Coordinates(lat, lng);
    // Use Karachi method consistently across the app
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.hanafi;
    return PrayerTimes.today(coordinates, params);
  }
}
