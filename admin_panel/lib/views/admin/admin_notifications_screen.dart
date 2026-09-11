import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:admin/view_models/theme_provider.dart';
import 'scholar_answer_view.dart';

// 👇 Yahan apni us screen ka import lazmi check kar lein ke woh kis folder mein hai
// Misal ke tor par:
// import 'package:admin/views/admin/scholar_answer_view.dart';

// 🔔 Bell Icon Widget (Admin Dashboard / AppBar ke liye)
class AdminBellIconWidget extends StatelessWidget {
  const AdminBellIconWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetRole', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        bool hasNewNotifications = unreadCount > 0;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications,
                color: hasNewNotifications ? Colors.red : Colors.green,
                size: 28,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminNotificationsScreen(),
                  ),
                );
              },
            ),
            if (hasNewNotifications)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// 📱 Admin Notifications Screen
class AdminNotificationsScreen extends StatelessWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Notifications"),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('targetRole', isEqualTo: 'admin')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications found."));
          }

          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            Timestamp? aTime = aData['timestamp'] ?? aData['createdAt'];
            Timestamp? bTime = bData['timestamp'] ?? bData['createdAt'];
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              bool isRead = data['isRead'] ?? false;

              String title = data['title'] ?? 'Notification';
              String message = data['message'] ?? data['body'] ?? '';

              return Card(
                color: isDark ? Colors.white10 : (isRead ? Colors.white : Colors.teal.shade50),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_active,
                    color: isRead ? Colors.grey : const Color(0xFF004D40),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    message,
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  trailing: !isRead
                      ? IconButton(
                    icon: const Icon(Icons.done_all, color: Colors.green),
                    tooltip: "Mark as read",
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(docId)
                          .update({'isRead': true});
                    },
                  )
                      : null,
                  onTap: () async {
                    // 1️⃣ Notification ko read mark karein
                    if (!isRead) {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(docId)
                          .update({'isRead': true});
                    }

                    // 2️⃣ Ab ScholarAnswerView screen par navigate ho jaye ga
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ScholarAnswerView(),
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