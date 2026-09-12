import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/timezone_helper.dart';
import '../utils/notification_time.dart';
import 'qaza_storage.dart';

@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Background notification tap: ${response.actionId} (ID: ${response.id})');
  
  if (response.id != null) {
    await NotificationService.plugin.cancel(response.id!);
  }

  await NotificationService.handleQazaAction(response.actionId);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Channel IDs are incremented to _v6 to force Android to recreate them fresh with sound settings.
  static const String prayerChannelId = 'prayer_alerts_v6';
  static const String qazaChannelId = 'qaza_checks_v6';
  static const String safarChannelId = 'safar_dua_channel_v6';

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
      onDidReceiveNotificationResponse: (details) async {
        debugPrint('Foreground notification tap: ${details.actionId} (ID: ${details.id})');
        if (details.id != null) {
          await plugin.cancel(details.id!);
        }
        await handleQazaAction(details.actionId);
      },
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

    // 🚀 Critical: Check if app was launched via a notification action button from a completely terminated state!
    try {
      final NotificationAppLaunchDetails? launchDetails = await plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final res = launchDetails.notificationResponse;
        if (res != null && res.actionId != null) {
          debugPrint('🚀 App launched from notification action: ${res.actionId}');
          if (res.id != null) {
            await plugin.cancel(res.id!);
          }
          await handleQazaAction(res.actionId);
        }
      }
    } catch (e) {
      debugPrint('Launch details check error: $e');
    }

    _initialized = true;
  }

  static Future<void> handleQazaAction(String? actionId) async {
    if (actionId == null) return;
    debugPrint('🚀 [NotificationService] Handling Action: $actionId');
    try {
      final prayer = QazaNotificationActions.prayerFrom(actionId);
      if (prayer == null) {
        debugPrint('⚠️ [NotificationService] Invalid prayer name in actionId: $actionId');
        return;
      }

      if (QazaNotificationActions.isNo(actionId)) {
        debugPrint('➕ [NotificationService] Incrementing Qaza for $prayer');
        final newVal = await QazaStorage.incrementQaza(prayer);
        debugPrint('✅ [NotificationService] New Qaza count for $prayer: $newVal');
      } else if (QazaNotificationActions.isYes(actionId)) {
        debugPrint('👌 [NotificationService] Prayed on time for $prayer');
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Action handler error: $e');
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
    audioAttributesUsage: AudioAttributesUsage.alarm, // Changed to alarm to ensure Azan audio stream bypasses notification muting on some devices
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
          styleInformation: BigTextStyleInformation(
            "سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ\n\nDon't forget to read Safar Dua for a blessed journey.",
            contentTitle: 'Traveling? 🚗 Safar Dua',
            summaryText: 'Travel Safety Reminder',
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );
      await plugin.show(
        888,
        'Traveling? 🚗 Safar Dua',
        "سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا...",
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
      debugPrint('📅 [NotificationService] Scheduling $name at $scheduledTime (Original: $time)');

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
      debugPrint('✅ [NotificationService] Scheduled $name successfully.');
    } catch (e) {
      debugPrint('❌ [NotificationService] Schedule error ($name): $e');
      try {
        debugPrint('⚠️ [NotificationService] Retrying with inexact schedule for $name...');
        final scheduledTime = NotificationTime.nextDailyInstance(time);
        await plugin.zonedSchedule(
          id,
          'Time for $name',
          "Allah-hu-Akbar! It's time for $name prayer.",
          scheduledTime,
          _prayerDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e2) {
        debugPrint('❌ [NotificationService] Fallback schedule error: $e2');
      }
    }
  }

  static Future<void> testInstant() async {
    if (kIsWeb) return;
    try {
      debugPrint('🔔 [NotificationService] Sending test notification...');
      await plugin.show(
        99,
        'حي على الصلاة',
        'Azan sound testing... Allah-hu-Akbar!',
        _prayerDetails,
      );
      debugPrint('✅ [NotificationService] Test notification sent.');
    } catch (e) {
      debugPrint('❌ [NotificationService] Test azan error: $e');
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
