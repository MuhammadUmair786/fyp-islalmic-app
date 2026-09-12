import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../theme/app_theme.dart';
import '../utils/auth_errors.dart';
import '../utils/input_validators.dart';
import '../widgets/app_logo.dart';
import '../widgets/google_logo.dart';
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

  bool get _busy => _isLoading || _isGoogleLoading;

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

  Future<void> _handleGoogleSignUp() async {
    if (_busy) return;
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
        serverClientId: _serverClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
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
          'displayName': InputValidators.sanitize(user.displayName) == ''
              ? 'Google User'
              : user.displayName,
          'email': user.email,
          'role': 'user',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(AuthErrors.fromFirebase(e), isError: true);
    } catch (e) {
      _showSnackBar(AuthErrors.fromAny(e), isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final String email = InputValidators.sanitizeEmail(_emailController.text);
    final String name = InputValidators.sanitize(_nameController.text);
    final String password = _passwordController.text;
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
      _showSnackBar(AuthErrors.fromFirebase(e), isError: true);
    } catch (e) {
      _showSnackBar(AuthErrors.fromAny(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            Flexible(child: Text('Verify Your Email')),
          ],
        ),
        content: Text(
          'A verification link has been sent to $email.\n\nPlease verify your email before logging in.',
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
            child: const Text('OK'),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(size.width < 360 ? 16 : size.width * 0.08),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding:
                  EdgeInsets.all(size.width < 360 ? 16 : size.width * 0.06),
              decoration: BoxDecoration(
                color:
                    isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? []
                    : [const BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: AppLogo(radius: 36)),
                    const SizedBox(height: 12),
                    Center(
                      child: FittedBox(
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : AppTheme.primaryLight,
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
                      'Full Name',
                      Icons.person_outline,
                      isDark,
                      textCapitalization: TextCapitalization.words,
                      validator: InputValidators.requiredName,
                    ),
                    SizedBox(height: size.height * 0.02),
                    _buildField(
                      _emailController,
                      'Email Address',
                      Icons.email_outlined,
                      isDark,
                      keyboardType: TextInputType.emailAddress,
                      validator: InputValidators.email,
                    ),
                    SizedBox(height: size.height * 0.02),
                    _buildField(
                      _passwordController,
                      'Password',
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
                      validator: (v) =>
                          InputValidators.password(v, requireStrength: true),
                    ),
                    SizedBox(height: size.height * 0.03),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? AppTheme.accentGreen
                              : AppTheme.primaryLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                'Create Account',
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
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('OR',
                              style: TextStyle(
                                  color:
                                      isDark ? Colors.white54 : Colors.grey)),
                        ),
                        Expanded(
                            child: Divider(
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300)),
                      ],
                    ),
                    SizedBox(height: size.height * 0.02),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.white10 : Colors.white,
                          side: BorderSide(
                              color:
                                  isDark ? Colors.white24 : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _busy ? null : _handleGoogleSignUp,
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
                                      'Sign Up with Google',
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String role, bool isDark) {
    bool isSel = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: _busy ? null : () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel
                ? (isDark ? AppTheme.accentGreen : AppTheme.primaryLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: FittedBox(
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
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
