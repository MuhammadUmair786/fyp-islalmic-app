import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TimezoneHelper {
  static const String fallbackLocation = 'Asia/Karachi';

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    String locationName = fallbackLocation;

    try {
      if (!kIsWeb) {
        locationName = await FlutterTimezone.getLocalTimezone();
      }
    } catch (e) {
      debugPrint('Timezone lookup failed, using $fallbackLocation: $e');
      locationName = fallbackLocation;
    }

    try {
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (e) {
      debugPrint('Invalid timezone "$locationName", falling back: $e');
      tz.setLocalLocation(tz.getLocation(fallbackLocation));
    }
  }
}
