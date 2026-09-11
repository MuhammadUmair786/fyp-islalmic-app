import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'scholar_dashboard.dart';
import 'scholar_details_screen.dart';
import '../theme/app_theme.dart';

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
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    } else {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (!userDoc.exists) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const LoginScreen()));
          return;
        }

        var userData = userDoc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? 'user';

        if (role == 'scholar') {
          bool isVerified = userData['isVerifiedScholar'] ?? false;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => isVerified ? const ScholarDashboard() : const ScholarDetailsScreen(),
            ),
          );
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const HomeScreen()));
        }
      } catch (e) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: Stack(
          children: [
            // Positioned(
            //   top: -50,
            //   right: -50,
            //   child: FadeInDown(
            //     duration: const Duration(seconds: 2),
            //     //child: Icon(Icons.mosque, size: 200, color: Colors.white.withValues(alpha: 0.03)),
            //   ),
            // ),
            
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
                      child: const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: AssetImage('assets/images/islamic_logo.png'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1500),
                    child: Column(
                      children: [
                        Text(
                          "Digital Islamic Hub",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your Spiritual Comapanion",
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                            letterSpacing: 0.5
                          ),
                        ),
                      ],
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
                delay: const Duration(seconds: 1),
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentGreen),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Loading App Data",
                        style: GoogleFonts.amiri(
                          color: Colors.white38,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
