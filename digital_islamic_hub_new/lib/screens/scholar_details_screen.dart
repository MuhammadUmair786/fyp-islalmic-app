import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'cloudinary_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ScholarDetailsScreen extends StatefulWidget {
  const ScholarDetailsScreen({super.key});

  @override
  State<ScholarDetailsScreen> createState() => _ScholarDetailsScreenState();
}

class _ScholarDetailsScreenState extends State<ScholarDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _degreeController = TextEditingController();

  String _selectedCountryCode = '+92';

  final List<Map<String, String>> _countryCodes = [
    {'name': 'Pakistan', 'code': '+92'},
    {'name': 'Saudi Arabia', 'code': '+966'},
    {'name': 'UAE', 'code': '+971'},
    {'name': 'UK', 'code': '+44'},
    {'name': 'USA', 'code': '+1'},
    {'name': 'India', 'code': '+91'},
  ];

  String? _selectedGender;
  String? _selectedPaymentMethod;

  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _paymentOptions = ['EasyPaisa', 'JazzCash', 'Both'];

  XFile? _pickedImageFile;
  Uint8List? _webImageBytes;
  bool _isLoading = false;

  Future<void> _pickSanadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _pickedImageFile = image;
        });
      } else {
        setState(() {
          _pickedImageFile = image;
        });
      }
    }
  }

  Future<String?> _uploadToCloudinary(String userId) async {
    if (_pickedImageFile == null) return null;
    try {
      CloudinaryResponse response;
      if (kIsWeb) {
        response = await CloudinaryService.cloudinary.uploadFile(
          CloudinaryFile.fromBytesData(
              _webImageBytes!,
              resourceType: CloudinaryResourceType.Image,
              identifier: 'degree_image_$userId'
          ),
        );
      } else {
        response = await CloudinaryService.cloudinary.uploadFile(
            CloudinaryFile.fromFile(_pickedImageFile!.path, resourceType: CloudinaryResourceType.Image)
        );
      }
      return response.secureUrl;
    } catch (e) {
      debugPrint("Cloudinary Error: $e");
      return null;
    }
  }

  Future<void> _submitDetails() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null || _selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Gender and Payment Method")));
      return;
    }
    if (_pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload certificate")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? imageUrl = await _uploadToCloudinary(user.uid);

      String formattedPhone = '$_selectedCountryCode${_phoneController.text.trim()}';

      await FirebaseFirestore.instance.collection('scholars').doc(user.uid).set({
        'phone': formattedPhone,
        'address': _addressController.text.trim(),
        'degree': _degreeController.text.trim(),
        'gender': _selectedGender,
        'payment_method': _selectedPaymentMethod,
        'image': imageUrl,
        'profileCompleted': true,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final notificationData = {
        'targetRole': 'admin',
        'title': 'Scholar Verification Request',
        'message': 'New scholar (${user.email ?? 'Scholar'}) has requested verification. Please review their application.',
        'userName': user.email ?? 'Scholar',
        'amountPaid': '0',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('notifications').add(notificationData);
      await FirebaseFirestore.instance.collection('admin_notifications').add(notificationData);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Request Submitted"),
          content: const Text("Aap ki application submit ho gayi hai. Admin approval के baad hi aap dashboard mein ja sakenge, please wait."),
          actions: [
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error Details"),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Scholar Verification", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
              );
            }
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 135,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white60 : Colors.grey.shade600),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            isExpanded: true,
                            dropdownColor: isDark ? AppTheme.primaryDark : Colors.white,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                            items: _countryCodes.map((country) {
                              return DropdownMenuItem<String>(
                                value: country['code'],
                                child: Text(
                                  '${country['name']} (${country['code']})',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white : Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCountryCode = val!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '3001234567',
                            labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Enter number";
                            }
                            if (v.trim().length < 9) {
                              return "Invalid number";
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    dropdownColor: isDark ? AppTheme.primaryDark : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                        labelText: 'Accept Payments via',
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                        border: const OutlineInputBorder()
                    ),
                    items: _paymentOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) => setState(() => _selectedPaymentMethod = val),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _addressController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                        labelText: 'Address',
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                        border: const OutlineInputBorder()
                    ),
                    validator: (v) => v!.isEmpty ? "Enter address" : null,
                  ),
                  const SizedBox(height: 20),

                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    dropdownColor: isDark ? AppTheme.primaryDark : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                        labelText: 'Gender',
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                        border: const OutlineInputBorder()
                    ),
                    items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _degreeController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                        labelText: 'Degree / Qualification',
                        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                        border: const OutlineInputBorder()
                    ),
                    validator: (v) => v!.isEmpty ? "Enter degree" : null,
                  ),
                  const SizedBox(height: 25),

                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Please upload certificate",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                        ),
                        const SizedBox(height: 12),

                        GestureDetector(
                          onTap: _pickSanadImage,
                          child: Container(
                            height: 180,
                            width: 320,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(10) : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            ),
                            child: _pickedImageFile == null
                                ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 40, color: isDark ? Colors.white30 : Colors.grey),
                                const SizedBox(height: 8),
                                Text("Tap to select certificate", style: TextStyle(color: isDark ? Colors.white30 : Colors.grey))
                              ],
                            )
                                : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                                  : Image.file(File(_pickedImageFile!.path), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                        foregroundColor: isDark ? AppTheme.primaryDark : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Submit Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
}