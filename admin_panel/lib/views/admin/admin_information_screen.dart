import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminInformationScreen extends StatefulWidget {
  const AdminInformationScreen({super.key});

  @override
  State<AdminInformationScreen> createState() => _AdminInformationScreenState();
}

class _AdminInformationScreenState extends State<AdminInformationScreen> {
  final _feeController = TextEditingController();
  final _easyPaisaNumController = TextEditingController();
  final _easyPaisaNameController = TextEditingController();
  final _jazzCashNumController = TextEditingController();
  final _jazzCashNameController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSettings();
  }

  void _loadExistingSettings() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('payment_details')
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data()!;
        setState(() {
          _feeController.text = data['feeAmount']?.toString() ?? '';
          _easyPaisaNumController.text = data['easyPaisaNumber'] ?? '';
          _easyPaisaNameController.text = data['easyPaisaName'] ?? '';
          _jazzCashNumController.text = data['jazzCashNumber'] ?? '';
          _jazzCashNameController.text = data['jazzCashName'] ?? '';
        });
      }
    } catch (e) {
      // Handle error quietly
    }
  }

  void _saveSettings() async {
    if (_feeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the Question Processing Fee!"), backgroundColor: Colors.red),
      );
      return;
    }

    bool hasEasyPaisa = _easyPaisaNumController.text.isNotEmpty || _easyPaisaNameController.text.isNotEmpty;
    bool hasJazzCash = _jazzCashNumController.text.isNotEmpty || _jazzCashNameController.text.isNotEmpty;

    if (!hasEasyPaisa && !hasJazzCash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill at least one payment method (EasyPaisa or JazzCash)!"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('payment_details')
          .set({
        'feeAmount': _feeController.text.trim(),
        'easyPaisaNumber': _easyPaisaNumController.text.trim(),
        'easyPaisaName': _easyPaisaNameController.text.trim(),
        'jazzCashNumber': _jazzCashNumController.text.trim(),
        'jazzCashName': _jazzCashNameController.text.trim(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin Information changed successfully! 🚀"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Information"),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Payment Details & Fee Management",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Here you can change and save details whenever you want, and they will update immediately.",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const Divider(height: 40),

                    // Fee Section
                    const Text("Question Processing Fee (Rs.)", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: "e.g: 50",
                        prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // EasyPaisa Section (Without Optional word)
                    const Text("EasyPaisa Account Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _easyPaisaNumController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: "EasyPaisa Mobile Number (e.g., 03001234567)",
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _easyPaisaNameController,
                      decoration: InputDecoration(
                        hintText: "Owner Name",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // JazzCash Section (Without Optional word)
                    const Text("JazzCash Account Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _jazzCashNumController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: "JazzCash Mobile Number (e.g., 03007654321)",
                        prefixIcon: const Icon(Icons.phone_android),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _jazzCashNameController,
                      decoration: InputDecoration(
                        hintText: "Owner Name",
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Save / Change Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isLoading ? null : _saveSettings,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Change & Save Settings ", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  void dispose() {
    _feeController.dispose();
    _easyPaisaNumController.dispose();
    _easyPaisaNameController.dispose();
    _jazzCashNumController.dispose();
    _jazzCashNameController.dispose();
    super.dispose();
  }
}