import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'scholar_questions_screen.dart';
import 'scholar_payments_screen.dart';

class ScholarNotificationsScreen extends StatelessWidget {
  final String currentScholarId;

  const ScholarNotificationsScreen({super.key, required this.currentScholarId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('scholarId', isEqualTo: currentScholarId)
            .where('targetRole', isEqualTo: 'scholar')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No notifications yet.",
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            );
          }

          var docs = snapshot.data!.docs;

          docs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            Timestamp? aTime = aData['createdAt'] ?? aData['timestamp'];
            Timestamp? bTime = bData['createdAt'] ?? bData['timestamp'];
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              String title = data['title'] ?? "Notification";
              String message = data['message'] ?? data['body'] ?? "";
              bool isRead = data['isRead'] ?? false;

              String formattedDate = '';
              var timestampField = data['createdAt'] ?? data['timestamp'];
              if (timestampField != null) {
                try {
                  Timestamp timestamp = timestampField;
                  DateTime dateTime = timestamp.toDate();
                  formattedDate = DateFormat('EEE, MMM d, yyyy - hh:mm a').format(dateTime);
                } catch (e) {
                  formattedDate = '';
                }
              }

              Future<void> handleTapOrRead() async {
                await FirebaseFirestore.instance
                    .collection('notifications')
                    .doc(docId)
                    .update({'isRead': true});

                if (context.mounted) {
                  final lowerTitle = title.toLowerCase();
                  final lowerMessage = message.toLowerCase();

                  if (lowerTitle.contains("payment") || lowerMessage.contains("payment") || lowerMessage.contains("sent")) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScholarPaymentsScreen(scholarId: currentScholarId),
                      ),
                    );
                  } else if (lowerTitle.contains("question") || lowerMessage.contains("question") || lowerMessage.contains("subscription") || lowerMessage.contains("pass")) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScholarQuestionsScreen(scholarId: currentScholarId),
                      ),
                    );
                  } else if (lowerTitle.contains("earning") || lowerMessage.contains("earnings") || lowerMessage.contains("ledger")) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScholarPaymentsScreen(scholarId: currentScholarId),
                      ),
                    );
                  }
                }
              }

              return Card(
                color: !isRead
                    ? AppTheme.accentGreen.withAlpha(isDark ? 50 : 30)
                    : (isDark ? Colors.white.withAlpha(12) : Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: !isRead
                        ? AppTheme.accentGreen.withAlpha(100)
                        : (isDark ? Colors.white10 : AppTheme.primaryLight.withAlpha(30)),
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: !isRead ? AppTheme.accentGreen : Colors.grey.shade400,
                    child: Icon(
                      Icons.notifications,
                      color: !isRead ? AppTheme.primaryDark : Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: !isRead ? FontWeight.bold : FontWeight.normal,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      if (isRead) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      ),
                      if (formattedDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: "Delete Notification",
                    onPressed: () async {
                      try {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(docId)
                            .delete();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Notification deleted successfully"),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint("Error deleting notification: $e");
                      }
                    },
                  ),
                  onTap: handleTapOrRead,
                ),
              );
            },
          );
        },
      ),
    );
  }
}