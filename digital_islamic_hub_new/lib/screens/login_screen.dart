import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_islamic_hub_new/screens/scholar_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';
import '../utils/auth_errors.dart';
import '../utils/input_validators.dart';
import '../widgets/app_logo.dart';
import '../widgets/google_logo.dart';
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
  bool _isResetLoading = false;
  bool _obscureText = true;

  static const String _serverClientId =
      '931378336633-dhctv1n5flrpbrcu56id5v5ccddgdjb8.apps.googleusercontent.com';

  bool get _busy => _isLoading || _isGoogleLoading || _isResetLoading;

  Future<void> _handleGoogleSignIn() async {
    if (_busy) return;
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: _serverClientId,
      );

      debugPrint('🚀 [GoogleSignIn] Starting signIn()...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('⚠️ [GoogleSignIn] User cancelled selection.');
        return;
      }
      debugPrint('✅ [GoogleSignIn] User: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        debugPrint('❌ [GoogleSignIn] idToken is NULL. Check SHA-1 and Firebase configuration.');
        _showSnackBar('Google Sign-In configuration error. Please contact support.', isError: true);
        return;
      }

      debugPrint('🔑 [GoogleSignIn] Got idToken: ${googleAuth.idToken?.substring(0, 10)}...');

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      debugPrint('🔥 [FirebaseAuth] Signing in...');
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
            'displayName': InputValidators.sanitize(user.displayName) == ''
                ? 'Google User'
                : user.displayName,
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
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [FirebaseAuthException] Code: ${e.code}, Message: ${e.message}');
      _showSnackBar(AuthErrors.fromFirebase(e), isError: true);
    } catch (e) {
      debugPrint('❌ [GoogleSignIn Error] $e');
      _showSnackBar(AuthErrors.fromAny(e), isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: InputValidators.sanitizeEmail(_emailController.text),
        password: _passwordController.text,
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        if (user != null && !user.emailVerified) {
          if (mounted) {
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

        // 🚀 Fix: If Firebase Auth user exists but no Firestore record, create it (Sync issue)
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'displayName': InputValidators.sanitize(user.displayName) == ''
              ? 'User'
              : user.displayName,
          'email': user.email,
          'role': 'user',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [Login Error] Code: ${e.code}, Message: ${e.message}');
      _showSnackBar(AuthErrors.fromFirebase(e), isError: true);
    } catch (e) {
      debugPrint('❌ [General Login Error] $e');
      _showSnackBar(AuthErrors.fromAny(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      _showSnackBar('Your scholar verification request was rejected.',
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
          'Email not verified. Please check your inbox or spam folder.',
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
              _showSnackBar('Verification email resent!', isError: false);
            } on FirebaseAuthException catch (e) {
              _showSnackBar(AuthErrors.fromFirebase(e), isError: true);
            } catch (_) {
              _showSnackBar('Failed to resend link.', isError: true);
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
            Flexible(child: Text('Application Pending')),
          ],
        ),
        content: const Text(
            'Your scholar application is currently pending admin approval.'),
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    if (_busy) return;
    final email = InputValidators.sanitizeEmail(_emailController.text);
    if (InputValidators.email(email) != null) {
      _showSnackBar('Please enter a valid email address first.', isError: true);
      return;
    }
    setState(() => _isResetLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnackBar('Password reset link sent to $email!', isError: false);
    } on FirebaseAuthException catch (e) {
      _showSnackBar(AuthErrors.fromFirebase(e), isError: true);
    } catch (e) {
      _showSnackBar(AuthErrors.fromAny(e), isError: true);
    } finally {
      if (mounted) setState(() => _isResetLoading = false);
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: size.width < 360 ? 16 : size.width * 0.08,
                vertical: 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const AppLogo(radius: 42),
                    const SizedBox(height: 16),
                    _buildHeaderTitle(isDark),
                    SizedBox(height: size.height * 0.03),
                    _buildFormContainer(isDark, context, size),
                    SizedBox(height: size.height * 0.03),
                    _buildSignUpFooter(isDark, context),
                  ],
                ),
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
        'Digital Islamic Hub',
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
      padding: EdgeInsets.all(size.width < 360 ? 16 : size.width * 0.06),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow:
            isDark ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: size.height * 0.03),
          _buildReusableTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            isDark: isDark,
            keyboardType: TextInputType.emailAddress,
            validator: InputValidators.email,
          ),
          SizedBox(height: size.height * 0.02),
          _buildReusableTextField(
            controller: _passwordController,
            label: 'Password',
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
            validator: InputValidators.loginPassword,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _handleForgotPassword,
              child: _isResetLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
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
              onPressed: _busy ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Login',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                child: Text('OR',
                    style:
                        TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
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
                    borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _busy ? null : _handleGoogleSignIn,
              child: _isGoogleLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.green),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GoogleLogo(),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Continue with Google',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
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

  Widget _buildReusableTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
      onTap: _busy
          ? null
          : () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SignUpScreen())),
      child: Text.rich(
        TextSpan(
          text: "Don't have an account? ",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          children: [
            TextSpan(
              text: 'Sign Up',
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
