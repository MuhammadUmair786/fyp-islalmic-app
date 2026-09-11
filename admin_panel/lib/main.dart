import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:admin/views/auth/login_view.dart';
import 'package:admin/views/admin/admin_dashboard_view.dart';
import 'package:admin/views/admin/profile_view.dart';
import 'package:admin/views/admin/user_management_hub_view.dart';
// import 'package:admin/views/admin/manage_users_view.dart'; // Commented out
import 'package:admin/views/admin/user_analytics_view.dart';
import 'package:admin/views/admin/scholar_management_hub_view.dart';
import 'package:admin/views/admin/manage_scholars_view.dart';
import 'package:admin/views/admin/scholar_analytics_view.dart';
import 'package:admin/views/admin/scholar_requests_view.dart';
import 'package:admin/views/admin/queries_payments_view.dart';
import 'package:admin/views/admin/sunnah_deeds_view.dart';
import 'package:admin/views/admin/upload_books_view.dart';
import 'package:admin/view_models/theme_provider.dart';
import 'package:admin/view_models/profile_view_model.dart';
import 'firebase_options.dart';
import 'package:admin/views/admin/scholar_answer_view.dart';

// Global Theme Colors
const Color primaryLight = Color(0xFF2E7D32); // Colors.green.shade800
const Color accentGreen = Color(0xFF004D40);
const Color primaryDark = Color(0xFF121212);
const Color cardDark = Color(0xFF1E1E1E);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Admin Panel',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: primaryLight,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            colorScheme: const ColorScheme.light(
              primary: primaryLight,
              secondary: accentGreen,
              surface: Colors.white,
            ),
            cardTheme: const CardThemeData(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryLight,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: primaryLight,
            scaffoldBackgroundColor: primaryDark,
            cardColor: cardDark,
            appBarTheme: const AppBarTheme(
              backgroundColor: cardDark,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            colorScheme: const ColorScheme.dark(
              primary: accentGreen,
              secondary: accentGreen,
              surface: cardDark,
            ),
            cardTheme: const CardThemeData(
              color: cardDark,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            useMaterial3: true,
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const LoginView(),
            '/dashboard': (context) => const AdminDashboardView(),
            '/profile': (context) => const ProfileView(),
            '/user_hub': (context) => const UserManagementHubView(),
            // '/manage_users': (context) => const ManageUsersView(), // Removed route since file doesn't exist
            '/user_analytics': (context) => const UserAnalyticsView(),
            '/scholar_hub': (context) => const ScholarManagementHubView(),
            '/manage_scholars': (context) => const ManageScholarsPage(),
            '/scholar_analytics': (context) => const ScholarAnalyticsView(),
            '/scholar_requests': (context) => const ScholarRequestsView(),
            '/scholar_answer': (context) => const ScholarAnswerView(),
            '/queries_payments': (context) => const QueriesPaymentsView(),
            '/sunnah_deeds': (context) => const SunnahDeedsView(),
            '/upload_books': (context) => const UploadBooksView(),
          },
        );
      },
    );
  }
}