import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  _UploadBookScreenState createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  File? _selectedPdfFile;
  String? _fileName;
  bool _isUploading = false;

  // --- CLOUDINARY CONFIGURATION ---
  // Yahan apni Cloudinary details dalein
  final String cloudName = 'YOUR_CLOUD_NAME';
  final String uploadPreset = 'YOUR_UPLOAD_PRESET'; // Unsigned preset hona chahiye

  // 1. PDF File Pick Karne Ka Function
  Future<void> _pickPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedPdfFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  // 2. Cloudinary Par PDF Upload Karne Ka Function
  Future<String?> _uploadToCloudinary(File pdfFile) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/raw/upload');

      var request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', pdfFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        // Cloudinary se secure URL return hoga
        return jsonData['secure_url'];
      } else {
        print('Upload Failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // 3. Form Submit & Upload Process
  Future<void> _submitBook() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first!')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    // Cloudinary par PDF upload karein
    String? pdfUrl = await _uploadToCloudinary(_selectedPdfFile!);

    if (pdfUrl != null) {
      // Yahan aap apna Database (Firebase / MongoDB / MySQL) ka code likh sakte hain
      // Jisme aap _titleController.text, _authorController.text, aur pdfUrl save karenge.

      print('Book Uploaded Successfully! URL: $pdfUrl');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book Uploaded Successfully!')),
      );

      // Form Reset karein
      _titleController.clear();
      _authorController.clear();
      setState(() {
        _selectedPdfFile = null;
        _fileName = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload PDF to Cloudinary.')),
      );
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Upload Book'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Book Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Book Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter book title'
                    : null,
              ),
              const SizedBox(height: 16),

              // Author Name
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter author name'
                    : null,
              ),
              const SizedBox(height: 20),

              // PDF Picker Button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 40, color: Colors.red[700]),
                    const SizedBox(height: 8),
                    Text(
                      _fileName ?? 'No PDF selected',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _pickPdfFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select PDF File'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Submit / Upload Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isUploading ? null : _submitBook,
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Upload Book',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}