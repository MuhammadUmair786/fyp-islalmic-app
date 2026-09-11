import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminWithdrawalRequest extends StatelessWidget {
  const AdminWithdrawalRequest({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text('Admin Withdrawal Request', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Sirf wo entries jahan scholar ne withdrawal request bhej di hai
        stream: FirebaseFirestore.instance
            .collection('scholar_earnings_ledger')
            .where('status', isEqualTo: 'withdrawal_requested')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No pending payout requests found.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var docId = docs[index].id;
              var data = docs[index].data() as Map<String, dynamic>;
              String scholarName = data['scholarName'] ?? 'Scholar';
              String scholarId = data['scholarId'] ?? '';
              double amount = double.tryParse(data['amount']?.toString() ?? '0') ?? 0.0;

              return FutureBuilder<DocumentSnapshot>(
                // Scholar ki profile se JazzCash/Bank details nikalne ke liye
                future: FirebaseFirestore.instance.collection('users').doc(scholarId).get(),
                builder: (context, userSnapshot) {
                  String paymentDetails = "Loading payment info...";
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    String accountTitle = userData['accountTitle'] ?? userData['name'] ?? 'N/A';
                    String accountNumber = userData['accountNumber'] ?? userData['phone'] ?? 'N/A';
                    String bankName = userData['bankName'] ?? userData['paymentMethod'] ?? 'JazzCash/EasyPaisa';
                    paymentDetails = "$bankName\nTitle: $accountTitle\nA/C: $accountNumber";
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Scholar: $scholarName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Text("Amount: RS $amount", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blueGrey.withOpacity(0.1)),
                            ),
                            child: Text(
                              paymentDetails,
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004D40),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text("Mark as Paid (Payment Sent)"),
                              onPressed: () => _markAsPaid(context, docId, scholarId, amount),
                            ),
                          ),
                        ],
                      ),
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

  // Jab admin manually payment bhej kar is button ko dabaye
  Future<void> _markAsPaid(BuildContext context, String docId, String scholarId, double amount) async {
    // 1. Ledger entry ka status 'paid' kar dein
    await FirebaseFirestore.instance.collection('scholar_earnings_ledger').doc(docId).update({
      'status': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
    });

    // 2. Scholar ko notification bhej dein
    await FirebaseFirestore.instance.collection('notifications').add({
      'targetId': scholarId,
      'targetRole': 'scholar',
      'title': 'Payment Transferred! 💸',
      'message': 'Your withdrawal request of RS $amount has been successfully paid by admin.',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payout marked as paid successfully!")),
      );
    }
  }
}