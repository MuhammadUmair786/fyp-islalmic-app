import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class UserAnswerScreen extends StatelessWidget {
  const UserAnswerScreen({super.key});

  void _showFullDetails(BuildContext context, DocumentSnapshot doc, bool isDark) async {
    var data = doc.data() as Map<String, dynamic>;
    String docId = doc.id;

    bool isViewed = data['isViewed'] ?? false;
    if (!isViewed && data['status'] == 'answered') {
      await FirebaseFirestore.instance
          .collection('user_questions')
          .doc(docId)
          .update({'isViewed': true});
    }

    String status = data['status'] ?? 'pending_verification';
    String scholarAnswerText = data['scholarResponse'] ?? data['scholarAnswer'] ?? data['answer'] ?? '';
    String scholarName = data['scholarName'] ?? "Scholar";
    String aiResponseText = data['aiResponse'] ?? data['aiAnswer'] ?? '';
    String paymentScreenshot = data['paymentScreenshot'] ?? data['screenshotUrl'] ?? data['imageUrl'] ?? '';

    Timestamp? timestamp = data['createdAt'];
    String formattedDate = '';
    if (timestamp != null) {
      formattedDate = DateFormat('EEE, dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
          title: Row(
            children: [
              Icon(Icons.verified_user_rounded, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Question & Scholar Answers",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppTheme.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (formattedDate.isNotEmpty)
                    Text("Date & Time: $formattedDate", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const Divider(height: 20),

                  Text("Your Question:", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(data['questionText'] ?? data['question'] ?? 'No text.', style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 15),

                  if (aiResponseText.isNotEmpty) ...[
                    const Text("Initial AI Answer:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(aiResponseText, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 15),
                  ],

                  if (status == 'answered' && scholarAnswerText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.accentGreen.withAlpha(20) : AppTheme.primaryLight.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppTheme.accentGreen.withAlpha(50) : AppTheme.primaryLight.withAlpha(30)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_pin, size: 18, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                              const SizedBox(width: 6),
                              Text(
                                "Answer by $scholarName",
                                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            scholarAnswerText,
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Row(
                      children: [
                        Icon(Icons.hourglass_top, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Scholar's answer is currently pending.", style: TextStyle(color: Colors.orange, fontSize: 13)),                      ],
                    ),
                  ],

                  if (paymentScreenshot.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    const Text("Payment Screenshot:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(paymentScreenshot, height: 150, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close", style: TextStyle(color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Answers")),
        body: const Center(child: Text("Please login to view your answers.")),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Scholar Answers", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_questions')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }

          var historyDocs = snapshot.data?.docs ?? [];

          if (historyDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.question_answer_outlined, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    "No scholar verifications requested yet.",
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          historyDocs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;

            Timestamp? timeA = dataA['createdAt'];
            Timestamp? timeB = dataB['createdAt'];

            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA);
          });

          return ListView.builder(
            itemCount: historyDocs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              var doc = historyDocs[index];
              var data = doc.data() as Map<String, dynamic>;

              String status = data['status'] ?? 'pending_verification';
              String scholarName = data['scholarName'] ?? "Assigned Scholar";
              bool isAnswered = status == 'answered';
              bool isViewed = data['isViewed'] ?? false;

              bool showAlertBadge = isAnswered && !isViewed;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.white10 : AppTheme.primaryLight.withAlpha(30)),
                ),
                color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                                child: Icon(Icons.school, size: 18, color: isDark ? AppTheme.primaryDark : Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    scholarName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'TID: ${data['transactionId'] ?? data['tid'] ?? 'N/A'}',
                                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: showAlertBadge
                                  ? Colors.orange.withOpacity(0.15)
                                  : (isAnswered ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              showAlertBadge ? "New Answer Received!"
                                  : (isAnswered ? "Viewed" : "Pending Review"),
                              style: TextStyle(
                                color: showAlertBadge
                                    ? Colors.orange.shade800
                                    : (isAnswered ? Colors.green.shade700 : Colors.grey.shade700),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showFullDetails(context, doc, isDark),
                            icon: Icon(Icons.visibility, size: 16, color: isDark ? AppTheme.primaryDark : Colors.white),
                            label: Text(
                              "View Full Details",
                              style: TextStyle(color: isDark ? AppTheme.primaryDark : Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
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