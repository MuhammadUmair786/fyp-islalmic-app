import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:digital_islamic_hub_new/screens/splash_screen.dart';
import 'package:digital_islamic_hub_new/services/notification_service.dart';
import 'package:digital_islamic_hub_new/services/qaza_notification_service.dart';
import 'package:digital_islamic_hub_new/theme/app_theme.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// Global Notifiers
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // 🌍 Initialize Timezones with safe default
  tz_data.initializeTimeZones();
  try {
    // Defaulting to Karachi timezone to ensure stability across devices
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
  } catch (e) {
    debugPrint("Timezone initialization fallback: $e");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔔 Initialize Notification Engines
  await NotificationService.init();
  await QazaNotificationService.init();

  final prefs = await SharedPreferences.getInstance();

  // Load saved preferences
  String savedLang = prefs.getString('app_language') ?? 'en';
  localeNotifier.value = Locale(savedLang);

  String savedTheme = prefs.getString('app_theme') ?? 'dark';
  themeNotifier.value = (savedTheme == 'light') ? ThemeMode.light : ThemeMode.dark;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, Locale currentLocale, child) {
            return MaterialApp(
              title: 'Digital Islamic Hub',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              locale: currentLocale,
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}