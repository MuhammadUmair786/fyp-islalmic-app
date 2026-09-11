import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../main.dart';
import 'login_screen.dart';

class ScholarProfileScreen extends StatefulWidget {
  const ScholarProfileScreen({super.key});

  @override
  State<ScholarProfileScreen> createState() => _ScholarProfileScreenState();
}

class _ScholarProfileScreenState extends State<ScholarProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _profileImageUrl;
  bool _isDarkMode = false;
  bool _isNotificationEnabled = true;
  bool _isUploading = false;
  final TextEditingController _nameController = TextEditingController();

  final String _cloudName = "lxuuhill";
  final String _uploadPreset = "AppPresent";

  @override
  void initState() {
    super.initState();
    _loadScholarData();
  }

  Future<void> _loadScholarData() async {
    if (user != null) {
      try {
        DocumentSnapshot doc = await _firestore.collection('scholars').doc(user!.uid).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
          if (mounted) {
            setState(() {
              _profileImageUrl = data['profileImage'];
              _isNotificationEnabled = data['notifications'] ?? true;
              _nameController.text = data['displayName'] ?? user?.displayName ?? "Scholar";

              if (data['darkMode'] != null) {
                _isDarkMode = data['darkMode'];
                themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
              } else {
                final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
                _isDarkMode = brightness == Brightness.dark;
                themeNotifier.value = ThemeMode.system;
              }
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _nameController.text = user?.displayName ?? "Scholar";
            });
          }
        }
      } catch (e) {
        debugPrint("Error loading scholar data: $e");
      }
    }
  }

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
    if (mounted) setState(() => _isUploading = true);

    try {
      var uri = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      var request = http.MultipartRequest("POST", uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
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
    await _firestore.collection('scholars').doc(user!.uid).set({
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Scholar Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Account Info", isDark),
                  _buildSettingsCard(isDark, [
                    _buildSettingsTile(
                      icon: Icons.person_outline,
                      title: "Display Name",
                      subtitle: _nameController.text.isEmpty ? "Set your name" : _nameController.text,
                      isDark: isDark,
                      onTap: () => _showEditNameDialog(),
                    ),
                    _buildSettingsTile(
                      icon: Icons.email_outlined,
                      title: "Email Address",
                      subtitle: user?.email ?? "scholar@hub.com",
                      isDark: isDark,
                    ),
                  ]),
                  const SizedBox(height: 25),
                  _buildSectionTitle("Settings & Analytics", isDark),
                  _buildSettingsCard(isDark, [
                    _buildSwitchTile(
                      icon: Icons.dark_mode_outlined,
                      title: "Dark Mode",
                      value: _isDarkMode,
                      color: Colors.blueAccent,
                      isDark: isDark,
                      onChanged: (val) {
                        setState(() => _isDarkMode = val);
                        _firestore.collection('scholars').doc(user!.uid).set({'darkMode': val}, SetOptions(merge: true));
                        themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                    _buildSwitchTile(
                      icon: Icons.notifications_none_outlined,
                      title: "Notifications",
                      value: _isNotificationEnabled,
                      color: Colors.orangeAccent,
                      isDark: isDark,
                      onChanged: (val) {
                        setState(() => _isNotificationEnabled = val);
                        _firestore.collection('scholars').doc(user!.uid).set({'notifications': val}, SetOptions(merge: true));
                      },
                    ),
                  ]),
                  const SizedBox(height: 40),
                  _buildLogoutButton(isDark),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 35, top: 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                      ? NetworkImage(_profileImageUrl!) as ImageProvider
                      : null,
                  child: _isUploading
                      ? const CircularProgressIndicator(color: AppTheme.primaryLight)
                      : (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 55, color: AppTheme.primaryLight)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 4,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickAndCropImage,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? AppTheme.accentGreen : Colors.orangeAccent,
                    child: Icon(Icons.edit, size: 16, color: isDark ? AppTheme.primaryDark : Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _nameController.text,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Verified Consultation Scholar",
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
            color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1
        ),
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.green.shade50),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required bool isDark, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: isDark ? AppTheme.accentGreen.withAlpha(25) : AppTheme.primaryLight.withAlpha(25),
            borderRadius: BorderRadius.circular(10)
        ),
        child: Icon(icon, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
      trailing: onTap != null ? const Icon(Icons.edit, color: Colors.grey, size: 18) : null,
    );
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required bool value, required Color color, required bool isDark, required Function(bool) onChanged}) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
      value: value,
      activeColor: AppTheme.accentGreen,
      onChanged: onChanged,
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.red.withAlpha(30) : Colors.red.shade50,
          foregroundColor: Colors.red,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: isDark ? Colors.red.withAlpha(50) : Colors.red.shade100)
          ),
        ),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
            );
          }
        },
        child: const Text("Logout Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  void _showEditNameDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
        title: Text("Edit Name", style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryLight)),
        content: TextField(
          controller: _nameController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: "Enter your name",
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
            ),
            onPressed: () async {
              await _firestore.collection('scholars').doc(user!.uid).set({
                'displayName': _nameController.text.trim()
              }, SetOptions(merge: true));
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: Text("Save", style: TextStyle(color: isDark ? AppTheme.primaryDark : Colors.white)),
          ),
        ],
      ),
    );
  }
}