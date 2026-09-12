import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/timezone_helper.dart';
import '../utils/notification_time.dart';
import 'qaza_storage.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Channel IDs are versioned so Android recreates them with Azan sound.
  static const String prayerChannelId = 'prayer_alerts_v2';
  static const String qazaChannelId = 'qaza_checks_v2';
  static const String safarChannelId = 'safar_dua_channel_v2';

  static Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;

    await TimezoneHelper.initialize();

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

    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    const AndroidNotificationChannel prayerChannel = AndroidNotificationChannel(
      prayerChannelId,
      'Prayer Notifications',
      description: 'Namaz ke auqat par Azan play karne ke liye',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('azan'),
      enableVibration: true,
    );

    const AndroidNotificationChannel qazaChannel = AndroidNotificationChannel(
      qazaChannelId,
      'Qaza Namaz Reminders',
      description: 'Reminders at the end of each prayer time',
      importance: Importance.max,
      playSound: true,
    );

    const AndroidNotificationChannel safarChannel = AndroidNotificationChannel(
      safarChannelId,
      'Safar Dua Reminders',
      description: 'Safar Dua reminders during travel',
      importance: Importance.max,
      playSound: true,
    );

    final androidImplementation = plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(prayerChannel);
      await androidImplementation.createNotificationChannel(qazaChannel);
      await androidImplementation.createNotificationChannel(safarChannel);
    }

    _initialized = true;
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) async {
    WidgetsFlutterBinding.ensureInitialized();
    await handleQazaAction(response.actionId);
  }

  static void _onDidReceiveNotificationResponse(
      NotificationResponse response) async {
    await handleQazaAction(response.actionId);
  }

  static Future<void> handleQazaAction(String? actionId) async {
    try {
      final prayer = QazaNotificationActions.prayerFrom(actionId);
      if (prayer == null || !QazaStorage.prayers.contains(prayer)) return;

      if (QazaNotificationActions.isNo(actionId)) {
        await QazaStorage.incrementQaza(prayer);
      }
      // Yes = prayed on time. Qaza count is left unchanged.
    } catch (e) {
      debugPrint('Qaza action error: $e');
    }
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        final android = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
        await android?.requestExactAlarmsPermission();
      } else if (Platform.isIOS) {
        await plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
  }

  static const AndroidNotificationDetails _prayerAndroidDetails =
      AndroidNotificationDetails(
    prayerChannelId,
    'Prayer Notifications',
    channelDescription: 'Namaz ke auqat par Azan play karne ke liye',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('azan'),
    audioAttributesUsage: AudioAttributesUsage.alarm,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
    visibility: NotificationVisibility.public,
    enableLights: true,
    enableVibration: true,
  );

  static const DarwinNotificationDetails _prayerIosDetails =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: 'azan.mp3',
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  static const NotificationDetails _prayerDetails = NotificationDetails(
    android: _prayerAndroidDetails,
    iOS: _prayerIosDetails,
  );

  static Future<void> showSafarDuaNotification() async {
    if (kIsWeb) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          safarChannelId,
          'Safar Dua Reminders',
          channelDescription: 'Safar Dua reminders during travel',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );
      await plugin.show(
        888,
        'Traveling? 🚗',
        "Don't forget to read Safar Dua for a blessed journey.",
        details,
      );
    } catch (e) {
      debugPrint('Safar notification error: $e');
    }
  }

  static Future<void> schedulePrayerNotification(
      int id, String name, DateTime time) async {
    if (kIsWeb) return;
    try {
      await init();
      final scheduledTime = NotificationTime.nextDailyInstance(time);

      await plugin.zonedSchedule(
        id,
        'Time for $name',
        "Allah-hu-Akbar! It's time for $name prayer.",
        scheduledTime,
        _prayerDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Schedule prayer notification error ($name): $e');
    }
  }

  static Future<void> testInstant() async {
    if (kIsWeb) return;
    try {
      await plugin.show(
        99,
        'حي على الصلاة',
        'Azan sound testing... Allah-hu-Akbar!',
        _prayerDetails,
      );
    } catch (e) {
      debugPrint('Test azan error: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    try {
      await plugin.cancel(id);
    } catch (e) {
      debugPrint('Cancel notification error: $e');
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.notificationTapBackground(response);
}
