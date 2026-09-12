import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_answer_screen.dart';
import 'user_book_list_view.dart'; // 👈 Book list screen ka import
import '../theme/app_theme.dart';

class UserNotificationScreen extends StatelessWidget {
  const UserNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("User Notifications", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No notifications yet!", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)));
          }

          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;

            String notifUserId = data['userId'] ?? data['uid'] ?? data['recipientId'] ?? '';
            String targetRole = data['targetRole'] ?? '';
            String title = (data['title'] ?? '').toString().toLowerCase();

            // 👈 Yeh filter scholar aur admin ke notifications ko user screen par aane se rokey ga (lekin 'all_users' ko allow karega)
            if (targetRole == 'scholar' || targetRole == 'admin') {
              return false;
            }

            if (notifUserId.isNotEmpty && notifUserId != currentUserId) {
              return false;
            }
            if (title.contains('new payment & question')) {
              return false;
            }
            return true;
          }).toList();

          if (docs.isEmpty) {
            return Center(child: Text("No notifications yet!", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              bool isRead = data['isRead'] ?? false;

              String title = data['title'] ?? 'Notification';
              String titleLower = title.toLowerCase();
              String targetRole = data['targetRole'] ?? '';
              String body = data['body'] ?? data['message'] ?? '';

              String formattedDate = '';
              var rawTimestamp = data['createdAt'] ?? data['timestamp'];
              if (rawTimestamp != null) {
                try {
                  Timestamp timestamp = rawTimestamp;
                  DateTime dateTime = timestamp.toDate();
                  formattedDate = DateFormat('MMM d, yyyy - hh:mm a').format(dateTime);
                } catch (e) {
                  formattedDate = '';
                }
              }

              return Card(
                color: !isRead
                    ? AppTheme.accentGreen.withAlpha(isDark ? 50 : 30)
                    : (isDark ? Colors.white.withAlpha(12) : Colors.white),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(
                    color: !isRead
                        ? AppTheme.accentGreen.withAlpha(100)
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: !isRead ? AppTheme.accentGreen : Colors.grey.shade400,
                    child: Icon(
                      Icons.notifications_active,
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
                      Text(body, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                      if (formattedDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.blueGrey,
                            fontWeight: FontWeight.w500,
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
                      } catch (e) {
                        debugPrint("Error deleting notification: $e");
                      }
                    },
                  ),
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(docId)
                        .update({'isRead': true});

                    if (context.mounted) {
                      // 👈 Agar notification book upload ka hai to UserBookListView par jayein, warna UserAnswerScreen par
                      if (targetRole == 'all_users' || titleLower.contains('book')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserBookListView(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserAnswerScreen(),
                          ),
                        );
                      }
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