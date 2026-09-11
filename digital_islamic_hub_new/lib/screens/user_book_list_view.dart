import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class UserBookListView extends StatefulWidget {
  const UserBookListView({super.key});

  @override
  State<UserBookListView> createState() => _UserBookListViewState();
}

class _UserBookListViewState extends State<UserBookListView> {

  // 🚀 Updated function to safely launch URL on both mobile and web
  Future<void> _openBookUrl(BuildContext context, String fileUrl, String title) async {
    final Uri url = Uri.parse(fileUrl.trim());
    try {
      // Direct launch ki koshish karein taake canLaunchUrl ki restriction avoid ho jaye
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );

      // Agar external application mein na khule toh platform default try karein
      if (!launched) {
        launched = await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );
      }

      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the book URL.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Islamic Books Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('uploaded_books').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No books available.', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)));
          }

          final books = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index].data() as Map<String, dynamic>;
              final String title = book['title'] ?? 'No Title';
              final String author = book['author'] ?? 'Unknown Author';
              final String pdfUrl = book['pdfUrl'] ?? '';

              return Card(
                elevation: isDark ? 0 : 3,
                margin: const EdgeInsets.only(bottom: 12),
                color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                    child: Icon(Icons.menu_book, color: isDark ? AppTheme.primaryDark : Colors.white),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Author: $author', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.visibility,
                      color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                      size: 26,
                    ),
                    onPressed: () {
                      if (pdfUrl.isNotEmpty) {
                        _openBookUrl(context, pdfUrl, title);
                      }
                    },
                    tooltip: 'View Book Online',
                  ),
                  onTap: () {
                    if (pdfUrl.isNotEmpty) {
                      _openBookUrl(context, pdfUrl, title);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}