import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../theme/app_theme.dart';

class PdfViewerScreen extends StatelessWidget {
  final String localPath;
  final String title;

  const PdfViewerScreen({super.key, required this.localPath, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: SfPdfViewer.file(
        File(localPath),
        canShowPaginationDialog: true,
        canShowScrollHead: true,
      ),
    );
  }
}