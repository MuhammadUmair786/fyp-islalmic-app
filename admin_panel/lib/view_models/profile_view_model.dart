import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:admin/view_models/theme_provider.dart'; // Apne ThemeProvider ka path yahan check kar Lein

class ProfileViewModel extends ChangeNotifier {
  String _adminName = "Administrator";
  String? _profileImageUrl;
  bool _isUploading = false;

  String get adminName => _adminName;
  String? get profileImageUrl => _profileImageUrl;
  bool get isUploading => _isUploading;

  final String cloudName = 'lxuuhill';
  final String uploadPreset = 'AppPresent';

  // 1. Admin Name Update karne ke liye
  void updateName(String newName) {
    _adminName = newName;
    notifyListeners();
  }

  // 2. Profile Image Pick & Upload (Cloudinary)
  Future<void> pickAndUploadProfileImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final fileBytes = result.files.single.bytes!;
        String fileName = result.files.single.name;

        _isUploading = true;
        notifyListeners();

        final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

        var request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
            ),
          );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        print('Cloudinary Status Code: ${response.statusCode}');
        print('Cloudinary Response Body: ${response.body}');

        if (response.statusCode == 200) {
          var jsonData = json.decode(response.body);
          _profileImageUrl = jsonData['secure_url'];
          notifyListeners();
        } else {
          debugPrint('Upload Failed: ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('Exception during upload: $e');
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  void updateProfileImageUrl(String url) {
    _profileImageUrl = url;
    notifyListeners();
  }

  // 3. Logout Function (Routes clear karke Login par bhejne ke liye)
  void logout(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  // 4. Dark / Light Mode Toggle Function
  void toggleTheme(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.toggleTheme(!themeProvider.isDarkMode);
    notifyListeners();
  }
}