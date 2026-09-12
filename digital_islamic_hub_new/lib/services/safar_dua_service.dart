import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/notification_time.dart';
import 'notification_service.dart';

class SafarDuaService {
  static const _lastTriggerKey = 'safar_dua_last_trigger_ms';
  static const _enabledKey = 'safar_dua_enabled';

  static StreamSubscription<Position>? _positionStream;
  static bool _starting = false;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'safarDuaReminder': enabled},
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Safar preference sync error: $e');
      }
    }

    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }

  static Future<DateTime?> lastTrigger() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastTriggerKey);
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> _markTriggered(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTriggerKey, now.millisecondsSinceEpoch);
  }

  static Future<void> startIfEnabled() async {
    if (await isEnabled()) {
      await start();
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final enabled = doc.data()?['safarDuaReminder'] ?? false;
      if (enabled == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_enabledKey, true);
        await start();
      }
    } catch (e) {
      debugPrint('Safar enabled lookup error: $e');
    }
  }

  static Future<void> start() async {
    if (kIsWeb || _starting) return;
    _starting = true;
    try {
      await stop();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      ).listen(_onPosition, onError: (e) {
        debugPrint('Safar position stream error: $e');
      });
    } catch (e) {
      debugPrint('Safar monitor start error: $e');
    } finally {
      _starting = false;
    }
  }

  static Future<void> _onPosition(Position position) async {
    try {
      final now = DateTime.now();
      final last = await lastTrigger();
      if (!SafarDuaPolicy.shouldTrigger(
        speedMs: position.speed,
        now: now,
        lastTrigger: last,
      )) {
        return;
      }

      await NotificationService.showSafarDuaNotification();
      await _markTriggered(now);
    } catch (e) {
      debugPrint('Safar trigger error: $e');
    }
  }

  static Future<void> stop() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
