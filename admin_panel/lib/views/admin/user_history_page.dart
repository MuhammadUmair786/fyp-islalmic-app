import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserHistoryPage extends StatelessWidget {
  const UserHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Payments History'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('user_questions').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }

          var records = snapshot.data?.docs ?? [];
          if (records.isEmpty) {
            return const Center(child: Text("No user incoming data available."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: records.length,
            itemBuilder: (context, index) {
              var data = records[index].data() as Map<String, dynamic>;

              String uName = data['userName'] ?? 'Unknown User';
              String uEmail = data['userEmail'] ?? 'No Email';
              String tId = data['transactionId'] ?? 'N/A';
              String amount = data['amountPaid'] ?? '0';
              String question = data['questionText'] ?? 'No Question Provided.';

              // Cloudinary URL extraction
              String? screenshotUrl = data['screenshot'] ?? data['paymentScreenshot'] ?? data['screenshotUrl'];

              String formattedDate = 'N/A Time';
              if (data['verifiedAt'] != null) {
                formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format((data['verifiedAt'] as Timestamp).toDate());
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(Icons.account_balance_wallet, color: Color(0xFF004D40)),
                  ),
                  title: Text(uName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('TID: $tId | Amount: PKR $amount\nDate: $formattedDate', style: const TextStyle(fontSize: 12, height: 1.4)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Text('📧 Email Address: $uEmail', style: const TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12),
                          const Text('❓ Submitted Question:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF5F7F8), borderRadius: BorderRadius.circular(8)),
                            child: Text(question, style: const TextStyle(fontSize: 13, height: 1.4)),
                          ),
                          const SizedBox(height: 16),
                          const Text('📸 Payment Slip Screenshot:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(8)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: (screenshotUrl != null && screenshotUrl.isNotEmpty)
                                  ? Image.network(
                                screenshotUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
                                },
                              )
                                  : const Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey)),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}