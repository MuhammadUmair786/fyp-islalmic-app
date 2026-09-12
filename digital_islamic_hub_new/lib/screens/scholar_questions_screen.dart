import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class ScholarQuestionsScreen extends StatelessWidget {
  final String scholarId;
  const ScholarQuestionsScreen({super.key, required this.scholarId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Consultation Inquiries", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_questions')
            .where('scholarId', isEqualTo: scholarId)
            .where('status', whereIn: ['sent_to_scholar', 'answered', 'pending_verification'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 60, color: isDark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      "No subscription inquiries found for this scholar.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          var docs = snapshot.data!.docs;
          Map<String, List<DocumentSnapshot>> userGroups = {};

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            String userId = data['userId'] ?? 'unknown_user';
            userGroups.putIfAbsent(userId, () => []).add(doc);
          }

          var userIds = userGroups.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              String userId = userIds[index];
              var userDocs = userGroups[userId]!;

              userDocs.sort((a, b) {
                Timestamp? timeA = (a.data() as Map<String, dynamic>)['createdAt'];
                Timestamp? timeB = (b.data() as Map<String, dynamic>)['createdAt'];
                if (timeA == null || timeB == null) return 0;
                return timeB.compareTo(timeA);
              });

              int pendingCount = userDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'sent_to_scholar' || (d.data() as Map<String, dynamic>)['status'] == 'pending_verification').length;

              var latestData = userDocs.first.data() as Map<String, dynamic>;
              String lastMessage = latestData['questionText'] ?? '';
              Timestamp? latestTimestamp = latestData['createdAt'];

              String formattedDate = 'Recent';
              if (latestTimestamp != null) {
                formattedDate = DateFormat('EEE, dd MMM yyyy, hh:mm a').format(latestTimestamp.toDate());
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  String displayName = "User";

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                    String? fetchedName = userData?['displayName'] ?? userData?['name'] ?? userData?['fullName'] ?? userData?['userName'];
                    String? fetchedEmail = userData?['email'] ?? userData?['userEmail'];

                    if (fetchedName != null && fetchedName.trim().isNotEmpty) {
                      displayName = fetchedName;
                    } else if (fetchedEmail != null && fetchedEmail.contains('@')) {
                      displayName = fetchedEmail.split('@').first;
                    } else {
                      displayName = "User ($userId)";
                    }
                  } else {
                    displayName = latestData['userName'] ?? latestData['name'] ?? "User";
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: isDark ? 0 : 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: CircleAvatar(
                        backgroundColor: isDark ? AppTheme.accentGreen.withAlpha(30) : AppTheme.primaryLight.withAlpha(15),
                        child: Icon(Icons.person, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "New Pass ($pendingCount)",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formattedDate,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? AppTheme.accentGreen : Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserChatDetailScreen(
                              userId: userId,
                              userName: displayName,
                              scholarId: scholarId,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class UserChatDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String scholarId;

  const UserChatDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.scholarId,
  });

  @override
  State<UserChatDetailScreen> createState() => _UserChatDetailScreenState();
}

class _UserChatDetailScreenState extends State<UserChatDetailScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (var controller in _controllers.values) controller.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer(String questionId, String answer, String userId, String scholarName) async {
    if (answer.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please write a consultation answer!")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance.collection('user_questions').doc(questionId).update({
        'scholarResponse': answer.trim(),
        'scholarName': scholarName,
        'status': 'answered',
        'answeredAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'targetRole': 'user',
        'userId': userId,
        'title': 'Consultation Answer Received! ✅',
        'message': 'Scholar ($scholarName) has answered your subscription inquiry.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'targetRole': 'admin',
        'title': 'Scholar Answered Subscription!',
        'message': 'Scholar ($scholarName) has submitted an answer to a consultation pass.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Answer sent successfully!"), backgroundColor: Colors.green));
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_questions')
            .where('scholarId', isEqualTo: widget.scholarId)
            .where('userId', isEqualTo: widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No subscription inquiries found for this user.",
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 16),
              ),
            );
          }

          var docs = snapshot.data!.docs;
          docs.sort((a, b) {
            Timestamp? timeA = (a.data() as Map<String, dynamic>)['createdAt'];
            Timestamp? timeB = (b.data() as Map<String, dynamic>)['createdAt'];
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String qId = doc.id;

              String questionText = data['questionText'] ?? "No Question Text";
              String aiAnswer = data['aiResponse'] ?? "No AI response recorded.";
              String scholarName = data['scholarName'] ?? 'Aalim';
              String status = data['status'] ?? 'pending_verification';
              bool isAnswered = status == 'answered';
              String scholarShare = data['scholarShare']?.toString() ?? '50';
              String? additionalNote = data['additionalNote'];

              Timestamp? timestamp = data['createdAt'];
              String formattedDateTime = 'Recent';
              if (timestamp != null) {
                formattedDateTime = DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(timestamp.toDate());
              }

              if (!_controllers.containsKey(qId)) {
                _controllers[qId] = TextEditingController(text: data['scholarResponse'] ?? "");
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 20),
                    elevation: isDark ? 0 : 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 18, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "User: ${widget.userName}",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formattedDateTime,
                                style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAnswered ? Colors.green.withAlpha(30) : Colors.orange.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  isAnswered ? "Answered" : "Pending Pass",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isAnswered ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "Share: RS $scholarShare",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          _buildInquiryBox(
                            title: "User Question",
                            content: questionText,
                            color: Colors.blue,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),

                          if (additionalNote != null && additionalNote.trim().isNotEmpty) ...[
                            _buildInquiryBox(
                              title: "Additional Note",
                              content: additionalNote,
                              color: Colors.purple,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 12),
                          ],

                          _buildInquiryBox(
                            title: "AI Reference Answer",
                            content: aiAnswer,
                            color: Colors.orange,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Icon(Icons.rate_review_outlined, size: 20, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                              const SizedBox(width: 8),
                              Text(
                                "Your Professional Answer:",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _controllers[qId],
                            maxLines: 5,
                            enabled: !isAnswered,
                            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Provide your expert verification...",
                              hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.all(15),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!isAnswered) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                                  foregroundColor: isDark ? AppTheme.primaryDark : Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _submitAnswer(qId, _controllers[qId]!.text, widget.userId, scholarName),
                                child: _isSubmitting
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("Submit Verification", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.withAlpha(50)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "Successfully submitted and verified.",
                                      style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildInquiryBox({required String title, required String content, required Color color, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? color.withAlpha(25) : color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }
}
