import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../services/safar_dua_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _profileImageUrl;
  bool _isDarkMode = false;
  bool _isNotificationEnabled = true;
  bool _isSafarDuaEnabled = false;
  bool _isUploading = false;

  String _selectedLanguage = 'en';
  final TextEditingController _nameController = TextEditingController();

  final String _cloudName = "lxuuhill";
  final String _uploadPreset = "AppPresent";

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('app_language') ?? 'en';
    });
  }

  Future<void> _changeLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);
    setState(() => _selectedLanguage = langCode);
    localeNotifier.value = Locale(langCode);
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      try {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user!.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
          if (mounted) {
            setState(() {
              _profileImageUrl = data['profileImage'];
              _isNotificationEnabled = data['notifications'] ?? true;
              _isSafarDuaEnabled = data['safarDuaReminder'] ?? false;
              _nameController.text = data['displayName'] ?? user?.displayName ?? "";
              _isDarkMode = data['darkMode'] ?? (themeNotifier.value == ThemeMode.dark);
            });
          }
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
    }
  }

  // 🖼️ Restore Image Picking Logic
  Future<void> _pickAndCropImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await showModalBottomSheet<XFile>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryLight),
              title: const Text('Gallery'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.gallery, imageQuality: 70)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryLight),
              title: const Text('Camera'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.camera, imageQuality: 70)),
            ),
          ],
        ),
      ),
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        await _uploadToCloudinary(bytes, pickedFile.name);
      } else {
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Profile Picture',
              toolbarColor: AppTheme.primaryLight,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
          ],
        );

        if (croppedFile != null) {
          final bytes = await croppedFile.readAsBytes();
          final fileName = croppedFile.path.split('/').last;
          await _uploadToCloudinary(bytes, fileName);
        }
      }
    }
  }

  Future<void> _uploadToCloudinary(Uint8List imageBytes, String fileName) async {
    setState(() => _isUploading = true);

    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      var request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        String secureUrl = jsonData['secure_url'];

        await _saveProfileImageUrl(secureUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture successfully updated!")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Upload failed. Please try again.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfileImageUrl(String imageUrl) async {
    await _firestore.collection('users').doc(user!.uid).set({
      'profileImage': imageUrl,
    }, SetOptions(merge: true));

    if (mounted) {
      setState(() {
        _profileImageUrl = imageUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            SizedBox(height: isSmallScreen ? 10 : 20),
            _buildCompactHeader(isDark),
            SizedBox(height: isSmallScreen ? 15 : 25),
            
            _buildSectionTitle("Settings", isDark),
            _buildSettingsCard(isDark, [
              _buildSettingsTile(
                icon: Icons.person_outline,
                title: "Display Name",
                subtitle: _nameController.text.isEmpty ? "Set your name" : _nameController.text,
                isDark: isDark,
                onTap: () => _showEditNameDialog(),
              ),
              ListTile(
                dense: true,
                leading: _tileIcon(Icons.language, isDark, Colors.teal),
                title: const Text("App Language", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    onChanged: (v) => _changeLanguage(v!),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text("English")),
                      DropdownMenuItem(value: 'ur', child: Text("اردو")),
                    ],
                  ),
                ),
              ),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: "Dark Mode",
                value: _isDarkMode,
                color: Colors.blueAccent,
                isDark: isDark,
                onChanged: (val) {
                  setState(() => _isDarkMode = val);
                  _firestore.collection('users').doc(user!.uid).update({'darkMode': val});
                  themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                },
              ),
              _buildSwitchTile(
                icon: Icons.notifications_none_outlined,
                title: "Prayer Alerts",
                value: _isNotificationEnabled,
                color: Colors.orangeAccent,
                isDark: isDark,
                onChanged: (val) {
                  setState(() => _isNotificationEnabled = val);
                  _firestore.collection('users').doc(user!.uid).update({'notifications': val});
                },
              ),
              _buildSwitchTile(
                icon: Icons.travel_explore_rounded,
                title: "Safar Dua Reminder",
                value: _isSafarDuaEnabled,
                color: Colors.cyan,
                isDark: isDark,
                onChanged: (val) async {
                  setState(() => _isSafarDuaEnabled = val);
                  try {
                    await SafarDuaService.setEnabled(val);
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isSafarDuaEnabled = !val);
                    }
                  }
                },
              ),
            ]),
            
            const SizedBox(height: 25),
            _buildLogoutButton(isDark),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader(bool isDark) {
    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _isUploading ? null : _pickAndCropImage,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.1),
                backgroundImage: (_profileImageUrl != null) ? NetworkImage(_profileImageUrl!) : null,
                child: (_profileImageUrl == null) ? const Icon(Icons.person, size: 40, color: AppTheme.accentGreen) : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _isUploading ? null : _pickAndCropImage,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.accentGreen,
                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                ),
              ),
            ),
            if (_isUploading) const Positioned.fill(child: CircularProgressIndicator(color: AppTheme.accentGreen, strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _nameController.text,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
        ),
        Text(user?.email ?? "", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 8),
        child: Text(title.toUpperCase(), style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _tileIcon(IconData icon, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required bool isDark, VoidCallback? onTap}) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: _tileIcon(icon, isDark, AppTheme.accentGreen),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required Color color, required bool isDark, required Function(bool) onChanged}) {
    return SwitchListTile(
      dense: true,
      secondary: _tileIcon(icon, isDark, color),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      value: value,
      activeThumbColor: AppTheme.accentGreen,
      onChanged: onChanged,
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity, height: 50,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.logout, size: 18),
        label: const Text("Logout Account", style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.1), foregroundColor: Colors.red, elevation: 0),
        onPressed: () => FirebaseAuth.instance.signOut().then((_) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()))),
      ),
    );
  }

  void _showEditNameDialog() {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Edit Name"),
      content: TextField(controller: _nameController),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        TextButton(onPressed: () async {
          final name = _nameController.text.trim();
          if (name.isEmpty) return;
          try {
            await _firestore.collection('users').doc(user!.uid).update({'displayName': name});
            if (mounted) setState(() {});
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save name. Please try again.')),
              );
            }
          }
          if (c.mounted) Navigator.pop(c);
        }, child: const Text("Save")),
      ],
    ));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
