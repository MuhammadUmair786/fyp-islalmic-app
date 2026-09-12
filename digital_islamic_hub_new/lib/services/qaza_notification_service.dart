import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/notification_time.dart';
import 'notification_service.dart';

class QazaNotificationService {
  static Future<void> init() async {
    await NotificationService.init();
  }

  /// Schedule reminders strictly at the QAZA / END TIME of each prayer.
  static Future<void> scheduleQazaChecks(PrayerTimes pt) async {
    if (kIsWeb) return;
    try {
      await NotificationService.init();

      await _scheduleCheck(101, 'Fajr', pt.sunrise);
      await _scheduleCheck(102, 'Dhuhr', pt.asr);
      await _scheduleCheck(103, 'Asr', pt.maghrib);
      await _scheduleCheck(104, 'Maghrib', pt.isha);

      final nextFajr = pt.fajr.add(const Duration(days: 1));
      await _scheduleCheck(105, 'Isha', nextFajr);
    } catch (e) {
      debugPrint('Qaza schedule error: $e');
    }
  }

  static Future<void> _scheduleCheck(
      int id, String prayer, DateTime qazaEndTime) async {
    try {
      final scheduledTime = NotificationTime.nextDailyInstance(qazaEndTime);
      debugPrint('📅 [QazaService] Scheduling $prayer check at $scheduledTime');

      await NotificationService.plugin.zonedSchedule(
        id,
        'Qaza Check: $prayer Namaz',
        'Time has run out: Have you offered the $prayer prayer?',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationService.qazaChannelId,
            'Qaza Namaz Reminders',
            channelDescription: 'Reminders at the end of each prayer time',
            importance: Importance.max,
            priority: Priority.high,
            actions: [
              AndroidNotificationAction(
                QazaNotificationActions.yesId(prayer),
                '✔️ Yes (Done)',
                showsUserInterface: true, // Opens app for "click feel"
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                QazaNotificationActions.noId(prayer),
                '❌ No (Qaza)',
                showsUserInterface: true, // Opens app for "click feel"
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: prayer,
      );
    } catch (e) {
      debugPrint('❌ [QazaService] Schedule error for $prayer: $e');
      // Fallback to inexact
      try {
        final scheduledTime = NotificationTime.nextDailyInstance(qazaEndTime);
        await NotificationService.plugin.zonedSchedule(
          id,
          'Qaza Check: $prayer Namaz',
          'Time has run out: Have you offered the $prayer prayer?',
          scheduledTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              NotificationService.qazaChannelId,
              'Qaza Namaz Reminders',
              channelDescription: 'Reminders at the end of each prayer time',
              importance: Importance.max,
              priority: Priority.high,
              actions: [
                AndroidNotificationAction(
                  QazaNotificationActions.yesId(prayer),
                  '✔️ Yes (Done)',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  QazaNotificationActions.noId(prayer),
                  '❌ No (Add to Qaza)',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ],
            ),
          ),
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: prayer,
        );
      } catch (e2) {
        debugPrint('❌ [QazaService] Fallback failed: $e2');
      }
    }
  }
}
