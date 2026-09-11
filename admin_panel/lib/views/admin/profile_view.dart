import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http; // Cloudinary multipart request ke liye
import 'package:admin/view_models/profile_view_model.dart';
import 'package:admin/view_models/theme_provider.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late TextEditingController _nameController;
  bool _isUploading = false;

  // ⚙️ TODO: Apne Cloudinary credentials yahan enter karein
  final String _cloudName = "lxuuhill";
  final String _uploadPreset = "AppPresent";

  @override
  void initState() {
    super.initState();
    final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
    _nameController = TextEditingController(text: profileVM.adminName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 🚀 Cloudinary Image Picker & Upload Function
  Future<void> _pickAndUploadImage(ProfileViewModel profileVM) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await showModalBottomSheet<XFile>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF004D40)),
              title: const Text('Gallery'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.gallery, imageQuality: 70)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF004D40)),
              title: const Text('Camera'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.camera, imageQuality: 70)),
            ),
          ],
        ),
      ),
    );

    if (pickedFile != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        Uint8List bytes = await pickedFile.readAsBytes();
        String fileName = kIsWeb ? pickedFile.name : pickedFile.path.split('/').last;

        // Agar mobile par hain toh Optional Cropper use kar sakte hain
        if (!kIsWeb) {
          CroppedFile? croppedFile = await ImageCropper().cropImage(
            sourcePath: pickedFile.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'Crop Profile Picture',
                toolbarColor: const Color(0xFF004D40),
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true,
              ),
            ],
          );
          if (croppedFile != null) {
            bytes = await croppedFile.readAsBytes();
            fileName = croppedFile.path.split('/').last;
          }
        }

        // Cloudinary Upload Request
        var uri = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
        var request = http.MultipartRequest("POST", uri)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

        var response = await request.send();
        if (response.statusCode == 200) {
          var responseData = await response.stream.bytesToString();
          var jsonData = json.decode(responseData);
          String secureUrl = jsonData['secure_url'];

          // ViewModel ke zariye profile image URL update karein
          profileVM.updateProfileImageUrl(secureUrl);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture successfully updated!')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cloudinary upload failed. Please try again.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileVM = Provider.of<ProfileViewModel>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Profile Picture Section
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundColor: const Color(0xFF004D40),
                      backgroundImage: profileVM.profileImageUrl != null && profileVM.profileImageUrl!.isNotEmpty
                          ? NetworkImage(profileVM.profileImageUrl!)
                          : null,
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : (profileVM.profileImageUrl == null || profileVM.profileImageUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 70, color: Colors.white)
                          : null,
                    ),
                    FloatingActionButton.small(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      onPressed: _isUploading ? null : () => _pickAndUploadImage(profileVM),
                      child: const Icon(Icons.camera_alt),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Name Change Section
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Personal Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.edit),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              profileVM.updateName(_nameController.text);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Name Updated!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004D40),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Update Name'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Settings Section (Dark Mode)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Dark Mode'),
                          subtitle: const Text('Change the appearance of the dashboard'),
                          secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                          value: isDark,
                          onChanged: (val) {
                            themeProvider.toggleTheme(val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Logout Section
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => profileVM.logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}