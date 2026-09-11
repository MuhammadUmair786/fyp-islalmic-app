import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'qaza_storage.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    } catch (_) {
      // Fallback
    }

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _notificationTapBackground,
    );

    // 🚀 High Importance Channels
    const AndroidNotificationChannel prayerChannel = AndroidNotificationChannel(
      'prayer_alerts',
      'Prayer Notifications',
      description: 'Namaz ke auqat par Azan play karne ke liye',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('azan'),
    );

    const AndroidNotificationChannel qazaChannel = AndroidNotificationChannel(
      'qaza_checks',
      'Qaza Namaz Reminders',
      description: 'Reminders to check missed prayers',
      importance: Importance.max,
    );

    const AndroidNotificationChannel safarChannel = AndroidNotificationChannel(
      'safar_dua_channel',
      'Safar Dua Reminders',
      description: 'Safar Dua reminders during travel',
      importance: Importance.max,
      playSound: true,
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(prayerChannel);
      await androidImplementation.createNotificationChannel(qazaChannel);
      await androidImplementation.createNotificationChannel(safarChannel);
    }
  }

  @pragma('vm:entry-point')
  static void _notificationTapBackground(NotificationResponse response) async {
    WidgetsFlutterBinding.ensureInitialized(); // 🚀 Required for background isolate
    if (response.actionId != null && response.actionId!.startsWith('no_')) {
      String prayer = response.actionId!.split('_')[1];
      await QazaStorage.incrementQaza(prayer);
    }
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) async {
    if (response.actionId != null && response.actionId!.startsWith('no_')) {
      String prayer = response.actionId!.split('_')[1];
      await QazaStorage.incrementQaza(prayer);
    }
  }

  static Future<void> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      } else if (Platform.isIOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint("Notification Permission error: $e");
    }
  }

  static Future<void> showSafarDuaNotification() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'safar_dua_channel',
        'Safar Dua Reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    );
    await _plugin.show(
      888,
      "Traveling? 🚗",
      "Don't forget to read Safar Dua for a blessed journey.",
      details,
    );
  }

  static Future<void> schedulePrayerNotification(
      int id, String name, DateTime time) async {
    final location = tz.local;
    var scheduledTime = tz.TZDateTime.from(time, location);

    if (scheduledTime.isBefore(tz.TZDateTime.now(location))) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      "Time for $name",
      "Allah-hu-Akbar! It's time for $name prayer.",
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_alerts',
          'Prayer Notifications',
          importance: Importance.max,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('azan'),
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      ),
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> testInstant() async {
    await _plugin.show(
      99,
      "حي على الصلاة",
      "Azan sound testing... Allah-hu-Akbar!",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_alerts',
          'Prayer Notifications',
          sound: RawResourceAndroidNotificationSound('azan'),
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}
