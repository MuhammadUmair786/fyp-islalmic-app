import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:digital_islamic_hub_new/utils/notification_time.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
  });

  test('rolls past prayer times to the next day', () {
    final past = DateTime.now().subtract(const Duration(hours: 2));
    final next = NotificationTime.nextDailyInstance(past);
    expect(next.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
  });

  test('parses qaza yes/no action ids', () {
    expect(QazaNotificationActions.noId('Fajr'), 'no_Fajr');
    expect(QazaNotificationActions.prayerFrom('no_Dhuhr'), 'Dhuhr');
    expect(QazaNotificationActions.isNo('no_Asr'), isTrue);
    expect(QazaNotificationActions.isYes('yes_Isha'), isTrue);
    expect(QazaNotificationActions.prayerFrom('open'), isNull);
  });

  group('SafarDuaPolicy', () {
    test('triggers once above 20 km/h and respects 4-hour cooldown', () {
      final now = DateTime(2026, 9, 12, 10);
      expect(
        SafarDuaPolicy.shouldTrigger(
            speedMs: 5.54, now: now, lastTrigger: null),
        isFalse,
      );
      expect(
        SafarDuaPolicy.shouldTrigger(
            speedMs: 5.55, now: now, lastTrigger: null),
        isTrue,
      );
      expect(
        SafarDuaPolicy.shouldTrigger(
          speedMs: 10,
          now: now,
          lastTrigger: now.subtract(const Duration(hours: 3, minutes: 59)),
        ),
        isFalse,
      );
      expect(
        SafarDuaPolicy.shouldTrigger(
          speedMs: 10,
          now: now,
          lastTrigger: now.subtract(const Duration(hours: 4)),
        ),
        isTrue,
      );
    });
  });
}
