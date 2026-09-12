import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:digital_islamic_hub_new/core/app_env.dart';
import 'package:digital_islamic_hub_new/core/timezone_helper.dart';
import 'package:digital_islamic_hub_new/screens/splash_screen.dart';
import 'package:digital_islamic_hub_new/services/notification_service.dart';
import 'package:digital_islamic_hub_new/services/qaza_notification_service.dart';
import 'package:digital_islamic_hub_new/theme/app_theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Removed preserve to allow instant transition to custom splash

  await AppEnv.load();
  await TimezoneHelper.initialize();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  try {
    await NotificationService.init();
    await QazaNotificationService.init();
  } catch (e) {
    debugPrint('Notification engine init error: $e');
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    localeNotifier.value = Locale(prefs.getString('app_language') ?? 'en');
    final savedTheme = prefs.getString('app_theme') ?? 'dark';
    themeNotifier.value =
        (savedTheme == 'light') ? ThemeMode.light : ThemeMode.dark;
  } catch (e) {
    debugPrint('Preference load error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, ThemeMode currentMode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, Locale currentLocale, _) {
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
