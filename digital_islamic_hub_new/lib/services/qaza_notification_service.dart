import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:adhan/adhan.dart';

class QazaNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // REDUNDANT: Initialization is now handled in NotificationService.init()
    // We just keep this for compatibility if called elsewhere.
  }

  /// Schedule reminders strictly at the QAZA / END TIME of each prayer
  static Future<void> scheduleQazaChecks(PrayerTimes pt) async {
    // 1. Fajr Qaza Check -> At Sunrise
    await _scheduleCheck(101, "Fajr", pt.sunrise);

    // 2. Dhuhr Qaza Check -> At Asr Start
    await _scheduleCheck(102, "Dhuhr", pt.asr);

    // 3. Asr Qaza Check -> At Sunset / Maghrib Start
    await _scheduleCheck(103, "Asr", pt.maghrib);

    // 4. Maghrib Qaza Check -> At Isha Start
    await _scheduleCheck(104, "Maghrib", pt.isha);

    // 5. Isha Qaza Check -> Next Day Fajr Start
    DateTime nextFajr = pt.fajr.add(const Duration(days: 1));
    await _scheduleCheck(105, "Isha", nextFajr);
  }

  static Future<void> _scheduleCheck(
      int id, String prayer, DateTime qazaEndTime) async {
    final scheduledTime = tz.TZDateTime.from(qazaEndTime, tz.local);

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      'Qaza Check: $prayer Namaz',
      'Waqt Khatam Ho Gaya Hai: Kya aap ne $prayer ki namaz ada kar li hai?',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'qaza_checks',
          'Qaza Namaz Reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'yes_$prayer',
              '✔️ Yes (Parh Li)',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'no_$prayer',
              '❌ No (Add to Qaza)',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
