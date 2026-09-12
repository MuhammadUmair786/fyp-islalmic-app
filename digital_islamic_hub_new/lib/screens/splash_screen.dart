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

    // Minimum display time (2.5 seconds) to ensure user can enjoy the beautiful splash
    const minDisplay = Duration(milliseconds: 2500);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minDisplay) {
      await Future.delayed(minDisplay - elapsed);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
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
        final status = (data['status'] ?? 'pending').toString().toLowerCase().trim();
        if (status == 'approved') return const ScholarDashboard();
        final hasPhoneAndImage = data.containsKey('phone') && data.containsKey('image');
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
    final logoRadius = size.shortestSide < 360 ? 45.0 : 55.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF002419), const Color(0xFF00110C), const Color(0xFF000806)]
                : [const Color(0xFF004D40), const Color(0xFF002419)],
          ),
        ),
        child: Stack(
          children: [
            // Background Decorative Elements
            Positioned(
              top: -50,
              right: -50,
              child: Opacity(
                opacity: 0.05,
                child: Icon(Icons.mosque, size: 250, color: AppTheme.accentGreen),
              ),
            ),
            
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with glow effect
                  ZoomIn(
                    duration: const Duration(milliseconds: 1200),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentGreen.withValues(alpha: 0.3),
                            blurRadius: 50,
                            spreadRadius: 10,
                          )
                        ],
                      ),
                      child: AppLogo(radius: logoRadius),
                    ),
                  ),
                  const SizedBox(height: 35),
                  
                  // App Name with specialized font
                  FadeInUp(
                    duration: const Duration(milliseconds: 1000),
                    delay: const Duration(milliseconds: 400),
                    child: Column(
                      children: [
                        Text(
                          'Digital Islamic Hub',
                          style: GoogleFonts.philosopher(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Tagline
                        Text(
                          'Your Spiritual Companion',
                          style: GoogleFonts.poppins(
                            color: AppTheme.accentGreen.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Loading Section
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: FadeIn(
                delay: const Duration(milliseconds: 800),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 60,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading App Data',
                      style: GoogleFonts.amiri(
                        color: Colors.white38,
                        fontSize: 16,
                        letterSpacing: 1.2,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
