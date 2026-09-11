import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_islamic_hub_new/screens/scholar_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'scholar_details_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscureText = true;

  static const String _serverClientId =
      '931378336633-dhctv1n5flrpbrcu56id5v5ccddgdjb8.apps.googleusercontent.com';

  bool _isValidEmail(String email) {
    final emailRegex =
    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: _serverClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      User? user = userCredential.user;

      if (user != null && mounted) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        DocumentSnapshot scholarDoc = await FirebaseFirestore.instance
            .collection('scholars')
            .doc(user.uid)
            .get();

        if (scholarDoc.exists) {
          _routeScholar(scholarDoc.data() as Map<String, dynamic>);
          return;
        }

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'uid': user.uid,
            'displayName': user.displayName ?? 'Google User',
            'email': user.email,
            'role': 'user',
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      _showSnackBar("Google Sign-In failed: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        UserCredential userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;

        if (user != null) {
          await user.reload();
          user = FirebaseAuth.instance.currentUser;

          if (user != null && !user.emailVerified) {
            if (mounted) {
              setState(() => _isLoading = false);
              _showUnverifiedEmailSnackBar(user);
            }
            return;
          }

          if (!mounted) return;

          DocumentSnapshot scholarDoc = await FirebaseFirestore.instance
              .collection('scholars')
              .doc(user!.uid)
              .get();

          if (scholarDoc.exists) {
            _routeScholar(scholarDoc.data() as Map<String, dynamic>);
            return;
          }

          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
              );
            }
            return;
          }

          _showSnackBar("User record not found in database.", isError: true);
        }
      } on FirebaseAuthException catch (e) {
        String message = "Authentication failed";
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          message = "You are not registered. Please create an account first.";
        } else if (e.code == 'wrong-password') {
          message = "Incorrect password. Please try again.";
        }
        _showSnackBar(message, isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _routeScholar(Map<String, dynamic> scholarData) {
    String status =
    (scholarData['status'] ?? 'pending').toString().toLowerCase().trim();

    if (status == 'approved') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ScholarDashboard()),
            (route) => false,
      );
    } else if (status == 'rejected') {
      _showSnackBar("Your scholar verification request was rejected.",
          isError: true);
      FirebaseAuth.instance.signOut();
    } else {
      bool hasPhoneAndImage =
          scholarData.containsKey('phone') && scholarData.containsKey('image');
      bool profileCompleted =
          scholarData['profileCompleted'] ?? hasPhoneAndImage;

      if (!profileCompleted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ScholarDetailsScreen()),
              (route) => false,
        );
      } else {
        _showPendingPopup();
      }
    }
  }

  void _showUnverifiedEmailSnackBar(User user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Email not verified. Please check your inbox or spam folder.",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orangeAccent,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'RESEND',
          textColor: Colors.black,
          onPressed: () async {
            try {
              await user.sendEmailVerification();
              _showSnackBar("Verification email resent!", isError: false);
            } catch (e) {
              _showSnackBar("Failed to resend link.", isError: true);
            }
          },
        ),
      ),
    );
  }

  void _showPendingPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.orange),
            SizedBox(width: 8),
            Text("Application Pending"),
          ],
        ),
        content: const Text(
            "Your scholar application is currently pending admin approval."),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      _showSnackBar("Please enter a valid email address first.", isError: true);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar("Password reset link sent to $email!", isError: false);
    } catch (e) {
      _showSnackBar("Error sending reset link.", isError: true);
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : AppTheme.primaryLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.primaryLight, AppTheme.primaryDark]
                : [const Color(0xFFE8F5E9), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildHeaderTitle(isDark),
                  SizedBox(height: size.height * 0.04),
                  _buildFormContainer(isDark, context, size),
                  SizedBox(height: size.height * 0.03),
                  _buildSignUpFooter(isDark, context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTitle(bool isDark) {
    return FittedBox(
      child: Text(
        "Digital Islamic Hub",
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppTheme.primaryLight,
        ),
      ),
    );
  }

  Widget _buildFormContainer(bool isDark, BuildContext context, Size size) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: EdgeInsets.all(size.width * 0.06),
      decoration: BoxDecoration(
        color:
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow:
        isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(
            "Welcome Back",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: size.height * 0.03),
          _buildReusableTextField(
            controller: _emailController,
            label: "Email Address",
            icon: Icons.email_outlined,
            isDark: isDark,
            validator: (val) =>
            (val == null || !_isValidEmail(val.trim()))
                ? "Enter a valid email address"
                : null,
          ),
          SizedBox(height: size.height * 0.02),
          _buildReusableTextField(
            controller: _passwordController,
            label: "Password",
            icon: Icons.lock_outline,
            isDark: isDark,
            obscureText: _obscureText,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Icons.visibility_off : Icons.visibility,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            validator: (val) =>
            (val == null || val.trim().isEmpty) ? "Password is required" : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              child: Text(
                "Forgot Password?",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                ),
              ),
            ),
          ),
          SizedBox(height: size.height * 0.015),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                foregroundColor: isDark ? AppTheme.primaryDark : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Login",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(height: size.height * 0.02),
          Row(
            children: [
              Expanded(
                  child: Divider(
                      color: isDark ? Colors.white24 : Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text("OR",
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
              ),
              Expanded(
                  child: Divider(
                      color: isDark ? Colors.white24 : Colors.grey.shade300)),
            ],
          ),
          SizedBox(height: size.height * 0.02),

          // Google Sign In Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? Colors.white10 : Colors.white,
                side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
              child: _isGoogleLoading
                  ? const CircularProgressIndicator(color: Colors.green)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGoogleLogo(),
                  const SizedBox(width: 12),
                  Text(
                    "Continue with Google",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }

  Widget _buildReusableTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon,
            color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
        suffixIcon: suffixIcon,
        enabledBorder: UnderlineInputBorder(
            borderSide:
            BorderSide(color: isDark ? Colors.white24 : Colors.grey)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
                color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight)),
      ),
      validator: validator,
    );
  }

  Widget _buildSignUpFooter(bool isDark, BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
      child: Text.rich(
        TextSpan(
          text: "Don't have an account? ",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          children: [
            TextSpan(
              text: "Sign Up",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint red = Paint()..color = const Color(0xFFEA4335);
    final Paint blue = Paint()..color = const Color(0xFF4285F4);
    final Paint green = Paint()..color = const Color(0xFF34A853);
    final Paint yellow = Paint()..color = const Color(0xFFFBBC05);

    final Path bluePath = Path()
      ..moveTo(w * 0.95, h * 0.5)
      ..cubicTo(w * 0.95, h * 0.45, w * 0.94, h * 0.4, w * 0.93, h * 0.35)
      ..lineTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.5, h * 0.53)
      ..lineTo(w * 0.76, h * 0.53)
      ..cubicTo(w * 0.74, h * 0.63, w * 0.68, h * 0.72, w * 0.58, h * 0.78)
      ..lineTo(w * 0.58, h * 0.96)
      ..lineTo(w * 0.73, h * 0.96)
      ..cubicTo(w * 0.88, h * 0.82, w * 0.95, h * 0.68, w * 0.95, h * 0.5);

    final Path greenPath = Path()
      ..moveTo(w * 0.5, h * 0.98)
      ..cubicTo(w * 0.67, h * 0.98, w * 0.82, h * 0.92, w * 0.92, h * 0.83)
      ..lineTo(w * 0.77, h * 0.71)
      ..cubicTo(w * 0.71, h * 0.75, w * 0.62, h * 0.78, w * 0.5, h * 0.78)
      ..cubicTo(w * 0.36, h * 0.78, w * 0.24, h * 0.68, w * 0.19, h * 0.56)
      ..lineTo(w * 0.04, h * 0.67)
      ..cubicTo(w * 0.14, h * 0.86, w * 0.31, h * 0.98, w * 0.5, h * 0.98);

    final Path yellowPath = Path()
      ..moveTo(w * 0.19, h * 0.56)
      ..cubicTo(w * 0.18, h * 0.52, w * 0.17, h * 0.48, w * 0.17, h * 0.44)
      ..cubicTo(w * 0.17, h * 0.40, w * 0.18, h * 0.36, w * 0.19, h * 0.32)
      ..lineTo(w * 0.04, h * 0.21)
      ..cubicTo(w * 0.01, h * 0.28, 0, h * 0.36, 0, h * 0.44)
      ..cubicTo(0, h * 0.52, w * 0.01, h * 0.60, w * 0.04, h * 0.67)
      ..lineTo(w * 0.19, h * 0.56);

    final Path redPath = Path()
      ..moveTo(w * 0.5, h * 0.18)
      ..cubicTo(w * 0.61, h * 0.18, w * 0.70, h * 0.22, w * 0.78, h * 0.29)
      ..lineTo(w * 0.91, h * 0.16)
      ..cubicTo(w * 0.81, h * 0.06, w * 0.67, 0, w * 0.5, 0)
      ..cubicTo(w * 0.31, 0, w * 0.14, h * 0.12, w * 0.04, h * 0.28)
      ..lineTo(w * 0.19, h * 0.4)
      ..cubicTo(w * 0.24, h * 0.28, w * 0.36, h * 0.18, w * 0.5, h * 0.18);

    canvas.drawPath(bluePath, blue);
    canvas.drawPath(greenPath, green);
    canvas.drawPath(yellowPath, yellow);
    canvas.drawPath(redPath, red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
