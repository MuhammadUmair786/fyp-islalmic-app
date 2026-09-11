import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_question_screen.dart';
import '../theme/app_theme.dart';

class ScholarListScreen extends StatelessWidget {
  final Map<String, dynamic> questionData;

  const ScholarListScreen({super.key, required this.questionData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Select a Scholar for Consultation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('scholars')
            .where('status', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading scholars."));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }

          var scholars = snapshot.data!.docs;

          if (scholars.isEmpty) {
            return Center(
              child: Text(
                "No Approved scholars found.",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: scholars.length,
            itemBuilder: (context, index) {
              var scholarDoc = scholars[index].data() as Map<String, dynamic>;
              String scholarId = scholars[index].id;

              String scholarName = scholarDoc['displayName'] ?? scholarDoc['email'] ?? 'Unknown Scholar';
              String? profileImg = scholarDoc['profileImage'];

              return Card(
                color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                elevation: isDark ? 0 : 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                    backgroundImage: (profileImg != null && profileImg.isNotEmpty) ? NetworkImage(profileImg) : null,
                    child: (profileImg == null || profileImg.isEmpty)
                        ? Icon(Icons.person, color: isDark ? AppTheme.primaryDark : Colors.white)
                        : null,
                  ),
                  title: Text(
                      scholarName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87
                      )
                  ),
                  subtitle: const Text("Verified Islamic Expert", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Icon(Icons.chevron_right, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserQuestionScreen(
                          question: questionData['questionText'] ?? "",
                          aiAnswer: questionData['aiAnswer'] ?? "",
                          selectedScholarId: scholarId,
                          selectedScholarName: scholarName,
                        ),
                      ),
                    );
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