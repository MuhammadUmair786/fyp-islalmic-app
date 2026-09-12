import 'package:timezone/timezone.dart' as tz;

class NotificationTime {
  /// Returns the next future instance of [time] in the local timezone.
  /// If [time] is already in the past, it is rolled forward by one day.
  static tz.TZDateTime nextDailyInstance(DateTime time) {
    final location = tz.local;
    var scheduled = tz.TZDateTime.from(time, location);
    final now = tz.TZDateTime.now(location);
    while (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

class QazaNotificationActions {
  static const yesPrefix = 'yes_';
  static const noPrefix = 'no_';

  static String yesId(String prayer) => '$yesPrefix$prayer';
  static String noId(String prayer) => '$noPrefix$prayer';

  static String? prayerFrom(String? actionId) {
    if (actionId == null) return null;
    if (actionId.startsWith(yesPrefix)) {
      return actionId.substring(yesPrefix.length);
    }
    if (actionId.startsWith(noPrefix)) {
      return actionId.substring(noPrefix.length);
    }
    return null;
  }

  static bool isNo(String? actionId) =>
      actionId != null && actionId.startsWith(noPrefix);

  static bool isYes(String? actionId) =>
      actionId != null && actionId.startsWith(yesPrefix);
}

class SafarDuaPolicy {
  static const double speedThresholdMs = 5.55; // 20 km/h
  static const Duration cooldown = Duration(hours: 4);

  static bool shouldTrigger({
    required double speedMs,
    required DateTime now,
    DateTime? lastTrigger,
  }) {
    if (speedMs < speedThresholdMs) return false;
    if (lastTrigger == null) return true;
    return now.difference(lastTrigger) >= cooldown;
  }
}
