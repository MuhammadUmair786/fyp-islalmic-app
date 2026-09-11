import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'scholar_requests_view.dart';
import 'queries_payments_view.dart';
import 'scholar_answer_view.dart';

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() => _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Notifications'),
        // AppBar color automatic global theme se aayega
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No notifications found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final targetRole = (data['targetRole'] ?? '').toString().toLowerCase();
            final title = (data['title'] ?? '').toString().toLowerCase();

            if (targetRole == 'user' || title.contains('submitted successfully')) {
              return false;
            }

            return targetRole == 'admin' ||
                title.contains('payment') ||
                title.contains('verification') ||
                title.contains('scholar') ||
                title.contains('answered');
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No admin notifications found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final notificationId = docs[index].id;
              final title = data['title'] ?? 'Notification';

              String formattedDate = '';
              if (data['createdAt'] != null) {
                try {
                  Timestamp timestamp = data['createdAt'];
                  DateTime dateTime = timestamp.toDate();
                  formattedDate = DateFormat('MMM d, yyyy - hh:mm a').format(dateTime);
                } catch (e) {
                  formattedDate = '';
                }
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // Theme colors implementation
                color: isDark ? theme.cardColor : theme.colorScheme.primary.withOpacity(0.08),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final lowerTitle = title.toLowerCase();

                    if (lowerTitle.contains('answered')) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ScholarAnswerView()));
                    } else if (lowerTitle.contains('scholar') || lowerTitle.contains('verification')) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ScholarRequestsView()));
                    } else if (lowerTitle.contains('payment')) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const QueriesPaymentsView()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Notification marked as read.")),
                      );
                    }

                    try {
                      await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();
                    } catch (e) {}
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary,
                          child: const Icon(Icons.notifications_active, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDark ? Colors.white : theme.colorScheme.primary,
                                ),
                              ),
                              if (formattedDate.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: isDark ? Colors.white70 : Colors.blueGrey, 
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
