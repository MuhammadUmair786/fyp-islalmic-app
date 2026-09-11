import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'dart:io';
import '../theme/app_theme.dart';

class UserQuestionScreen extends StatefulWidget {
  final String question;
  final String aiAnswer;
  final String selectedScholarId;
  final String selectedScholarName;

  const UserQuestionScreen({
    super.key,
    required this.question,
    required this.aiAnswer,
    required this.selectedScholarId,
    required this.selectedScholarName,
  });

  @override
  State<UserQuestionScreen> createState() => _UserQuestionScreenState();
}

class _UserQuestionScreenState extends State<UserQuestionScreen> {
  final _tidController = TextEditingController();
  final _amountController = TextEditingController();
  final _suggestionController = TextEditingController();
  bool _isLoading = false;

  XFile? _selectedImage;
  String? _paymentProofUrl;
  bool _isUploadingImage = false;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
        await _uploadToCloudinary(pickedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image Picker Error: $e")));
      }
    }
  }

  Future<void> _uploadToCloudinary(XFile imageFile) async {
    setState(() => _isUploadingImage = true);
    try {
      CloudinaryResponse response;

      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        response = await CloudinaryService.cloudinary.uploadFile(
          CloudinaryFile.fromByteData(
            bytes.buffer.asByteData(),
            identifier: imageFile.name,
            resourceType: CloudinaryResourceType.Image,
            folder: 'payment_proofs',
          ),
        );
      } else {
        response = await CloudinaryService.cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            imageFile.path,
            resourceType: CloudinaryResourceType.Image,
            folder: 'payment_proofs',
          ),
        );
      }

      if (response.secureUrl.isNotEmpty) {
        setState(() {
          _paymentProofUrl = response.secureUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment screenshot uploaded successfully!")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(" Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _submitRequest() async {
    if (_amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter paid amount")));
      return;
    }
    if (_tidController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Transaction ID")));
      return;
    }
    if (_paymentProofUrl == null || _paymentProofUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload payment screenshot")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String userName = 'User';

      if (user != null) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists && userDoc.data() != null) {
            var userData = userDoc.data() as Map<String, dynamic>;
            userName = userData['name'] ?? userData['fullName'] ?? user.displayName ?? user.email?.split('@').first ?? 'User';
          } else {
            userName = user.displayName ?? user.email?.split('@').first ?? 'User';
          }
        } catch (e) {
          userName = user.displayName ?? user.email?.split('@').first ?? 'User';
        }
      }

      String enteredAmount = _amountController.text.trim();

      DocumentReference questionDoc = await FirebaseFirestore.instance.collection('user_questions').add({
        'userId': user?.uid ?? 'anonymous',
        'userName': userName,
        'userEmail': user?.email ?? '',
        'questionText': widget.question,
        'aiResponse': widget.aiAnswer,
        'scholarId': widget.selectedScholarId,
        'scholarName': widget.selectedScholarName,
        'amountPaid': enteredAmount,
        'transactionId': _tidController.text.trim(),
        'paymentProofUrl': _paymentProofUrl,
        'additionalNote': _suggestionController.text.trim(),
        'status': 'pending_verification',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'targetRole': 'admin',
        'questionId': questionDoc.id,
        'userName': userName,
        'amountPaid': enteredAmount,
        'title': 'New Consultation Subscription Payment!',
        'message': '$userName subscribed for scholar consultation with a payment of Rs $enteredAmount.',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subscription request submitted successfully!"), backgroundColor: AppTheme.primaryLight));
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Submission Error"),
            content: Text("Masla aa raha hai: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
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
        title: const Text("Consultation Subscription", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('app_settings').doc('payment_details').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(width: 150, child: LinearProgressIndicator());
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isDark ? Colors.white10 : AppTheme.primaryLight.withAlpha(10), borderRadius: BorderRadius.circular(8)),
                      child: Text("No payment info", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                    );
                  }

                  var paymentData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

                  String epName = paymentData['easyPaisaName'] ?? '';
                  String epNumber = paymentData['easyPaisaNumber'] ?? '';
                  String jpName = paymentData['jazzCashName'] ?? '';
                  String jpNumber = paymentData['jazzCashNumber'] ?? '';

                  return Container(
                    width: 270,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(10) : AppTheme.primaryLight.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppTheme.accentGreen.withAlpha(50) : AppTheme.primaryLight.withAlpha(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Subscription Fee: ${paymentData['feeAmount'] ?? 'N/A'} PKR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight)),
                        const Divider(height: 8),

                        if (epName.isNotEmpty || epNumber.isNotEmpty) ...[
                          Text("EasyPaisa: $epName - $epNumber", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                          const SizedBox(height: 4),
                        ],

                        if (jpName.isNotEmpty || jpNumber.isNotEmpty) ...[
                          Text("JazzCash: $jpName - $jpNumber", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 30),
            Text("Your Question:", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(widget.question, style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 10),
            Text("AI Answer Reference:", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(widget.aiAnswer, style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey)),
            const SizedBox(height: 20),

            TextField(
              controller: _suggestionController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Additional Note / Question (Optional)",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                hintText: "Could I share an extra thought with you regarding this topic?",
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Paid Amount (e.g., 100)",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                border: const OutlineInputBorder(),
                hintText: "Enter exact subscription fee paid",
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _tidController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Transaction ID",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                border: const OutlineInputBorder(),
                hintText: "Enter your payment TID",
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
              ),
            ),
            const SizedBox(height: 20),

            Text("Upload Payment Screenshot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),

            Center(
              child: SizedBox(
                width: 500,
                height: 200,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                      color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade100,
                    ),
                    child: _isUploadingImage
                        ? Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
                        : _paymentProofUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? Image.network(_paymentProofUrl!, fit: BoxFit.cover)
                          : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 40, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            "Click here to upload payment screenshot",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                  foregroundColor: isDark ? AppTheme.primaryDark : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Submit Subscription Request", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}