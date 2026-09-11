import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'user';

  static const String _serverClientId =
      '931378336633-dhctv1n5flrpbrcu56id5v5ccddgdjb8.apps.googleusercontent.com';

  bool _isValidEmail(String email) {
    final emailRegex =
    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  String? _validateStrongPassword(String? value) {
    if (value == null || value.trim().isEmpty) return "Password is required";
    if (value.length < 6) return "Password must be at least 6 characters long";
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return "Password must contain letters";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return "Password must contain numbers";
    }
    return null;
  }

  Future<void> _handleGoogleSignUp() async {
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
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'displayName': user.displayName ?? 'Google User',
          'email': user.email,
          'role': 'user',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-Up failed: ${e.toString()}")),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final String email = _emailController.text.trim();
      final String name = _nameController.text.trim();
      final String password = _passwordController.text.trim();
      final String finalRole = _selectedRole;

      try {
        UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final user = userCredential.user;
        if (user != null) {
          await user.sendEmailVerification();

          if (finalRole == 'scholar') {
            await FirebaseFirestore.instance
                .collection('scholars')
                .doc(user.uid)
                .set({
              'uid': user.uid,
              'displayName': name,
              'email': email,
              'role': 'scholar',
              'status': 'pending',
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
              'uid': user.uid,
              'displayName': name,
              'email': email,
              'role': 'user',
              'status': 'active',
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          if (mounted) {
            _showVerificationNoticeDialog(email);
          }
        }
      } on FirebaseAuthException catch (e) {
        String msg = e.message ?? "Failed to create account";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showVerificationNoticeDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread, color: Colors.green),
            SizedBox(width: 8),
            Text("Verify Your Email"),
          ],
        ),
        content: Text(
          "A verification link has been sent to $email.\n\nPlease verify your email before logging in.",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryLight,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.primaryDark : const Color(0xFFE8F5E9),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(size.width * 0.08),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: EdgeInsets.all(size.width * 0.06),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow:
              isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: FittedBox(
                      child: Text(
                        "Create Account",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _buildRoleTab('user', isDark),
                        _buildRoleTab('scholar', isDark),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.025),
                  _buildField(
                    _nameController,
                    "Full Name",
                    Icons.person_outline,
                    isDark,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? "Full Name is required"
                        : null,
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildField(
                    _emailController,
                    "Email Address",
                    Icons.email_outlined,
                    isDark,
                    validator: (v) => _isValidEmail(v?.trim() ?? "")
                        ? null
                        : "Enter a valid email address",
                  ),
                  SizedBox(height: size.height * 0.02),
                  _buildField(
                    _passwordController,
                    "Password",
                    Icons.lock_outline,
                    isDark,
                    obscure: _obscurePassword,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: isDark ? Colors.white60 : Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: _validateStrongPassword,
                  ),
                  SizedBox(height: size.height * 0.03),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        "Create Account",
                        style: TextStyle(
                          color: isDark ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white10 : Colors.white,
                        side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isGoogleLoading ? null : _handleGoogleSignUp,
                      child: _isGoogleLoading
                          ? const CircularProgressIndicator(color: Colors.green)
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildGoogleLogo(),
                          const SizedBox(width: 12),
                          Text(
                            "Sign Up with Google",
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
            ),
          ),
        ),
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

  Widget _buildRoleTab(String role, bool isDark) {
    bool isSel = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel
                ? (isDark ? AppTheme.accentGreen : AppTheme.primaryLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              role.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSel
                    ? (isDark ? AppTheme.primaryDark : Colors.white)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      TextEditingController ctrl,
      String lbl,
      IconData icon,
      bool isDark, {
        bool obscure = false,
        Widget? suffix,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: lbl,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon,
            color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
        suffixIcon: suffix,
      ),
      validator: validator,
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
