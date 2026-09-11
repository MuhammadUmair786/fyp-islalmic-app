import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QazaStorage {
  static const List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static final ValueNotifier<int> qazaUpdated = ValueNotifier<int>(0);

  static String _key(String prayer) => 'qaza_count_$prayer';

  static String previousPrayer(String currentPrayer) {
    final idx = prayers.indexOf(currentPrayer);
    if (idx <= 0) return prayers.last; // Fajr -> Isha (Previous Night)
    return prayers[idx - 1];
  }

  static Future<int> incrementQaza(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key(prayer)) ?? 0;
    final updated = current + 1;
    await prefs.setInt(_key(prayer), updated);
    qazaUpdated.value++;
    return updated;
  }

  static Future<int> decrementQaza(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_key(prayer)) ?? 0;
    if (current <= 0) return 0;
    final updated = current - 1;
    await prefs.setInt(_key(prayer), updated);
    qazaUpdated.value++;
    return updated;
  }

  static Future<int> getQaza(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(prayer)) ?? 0;
  }

  static Future<Map<String, int>> getAllQaza() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final p in prayers) p: prefs.getInt(_key(p)) ?? 0,
    };
  }

  static Future<int> getTotalQaza() async {
    final all = await getAllQaza();
    return all.values.fold<int>(0, (sum, v) => sum + v);
  }
}