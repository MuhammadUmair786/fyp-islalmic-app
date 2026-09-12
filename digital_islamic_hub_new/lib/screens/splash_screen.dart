import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'scholar_dashboard.dart';
import 'scholar_details_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final started = DateTime.now();
    Widget destination = const LoginScreen();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        destination = await _destinationForUser(user);
      }
    } catch (e) {
      debugPrint('Splash routing error: $e');
      destination = const LoginScreen();
    }

    const minDisplay = Duration(milliseconds: 1600);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minDisplay) {
      await Future.delayed(minDisplay - elapsed);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  Future<Widget> _destinationForUser(User user) async {
    try {
      final scholarDoc = await FirebaseFirestore.instance
          .collection('scholars')
          .doc(user.uid)
          .get();

      if (scholarDoc.exists) {
        final data = scholarDoc.data() as Map<String, dynamic>;
        final status =
            (data['status'] ?? 'pending').toString().toLowerCase().trim();
        if (status == 'approved') return const ScholarDashboard();
        final hasPhoneAndImage =
            data.containsKey('phone') && data.containsKey('image');
        final profileCompleted = data['profileCompleted'] ?? hasPhoneAndImage;
        if (profileCompleted != true) return const ScholarDetailsScreen();
        return const LoginScreen();
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) return const HomeScreen();
    } catch (e) {
      debugPrint('Splash user lookup error: $e');
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final logoRadius = size.shortestSide < 360 ? 42.0 : 50.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF002419), const Color(0xFF00110C)]
                : [AppTheme.primaryLight, AppTheme.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeInDown(
                      duration: const Duration(milliseconds: 1500),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentGreen.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: AppLogo(radius: logoRadius),
                      ),
                    ),
                    const SizedBox(height: 30),
                    FadeInUp(
                      duration: const Duration(milliseconds: 1500),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            FittedBox(
                              child: Text(
                                'Digital Islamic Hub',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your Spiritual Companion',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: FadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accentGreen),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Loading App Data',
                        style: GoogleFonts.amiri(
                          color: Colors.white38,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
