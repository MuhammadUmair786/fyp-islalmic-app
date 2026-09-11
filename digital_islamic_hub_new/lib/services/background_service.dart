import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

Future<void> initializeBackgroundService() async {
  // 1. Guard against Web first to avoid evaluating TargetPlatform on web
  if (kIsWeb) return;

  // 2. Guard against unsupported desktop platforms (Windows, macOS, Linux)
  final isSupportedMobilePlatform =
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;

  if (!isSupportedMobilePlatform) return;

  // 3. Safe to instantiate FlutterBackgroundService only on Android & iOS
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'masjid_auto_silent_channel',
      initialNotificationTitle: 'Masjid Auto-Silent',
      initialNotificationContent: 'Initializing location service...',
      foregroundServiceNotificationId: 888, // Recommended ID for persistent foreground notification
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Background location checking logic goes here
}