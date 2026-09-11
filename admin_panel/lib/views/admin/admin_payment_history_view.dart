import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPaymentHistoryView extends StatelessWidget {
  const AdminPaymentHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text('Verified Payment History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Yahan se .orderBy hata diya hai taake index ka error na aaye
        stream: FirebaseFirestore.instance
            .collection('user_questions')
            .where('status', isEqualTo: 'sent_to_scholar')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No payment history found yet.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            );
          }

          var docs = snapshot.data!.docs;

          // Yahan hum code ke zariye khud latest items ko top par sort kar rahe hain
          docs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            Timestamp? timeA = dataA['verifiedAt'];
            Timestamp? timeB = dataB['verifiedAt'];
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA); // Descending order (latest first)
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String userName = data['userName'] ?? data['name'] ?? 'User';
              String scholarName = data['scholarName'] ?? data['requestedScholarName'] ?? 'Scholar';
              double totalAmount = double.tryParse(data['totalAmount']?.toString() ?? data['amountPaid']?.toString() ?? '0') ?? 0.0;
              double scholarShare = double.tryParse(data['scholarShare']?.toString() ?? '0') ?? (totalAmount / 2);
              double adminShare = double.tryParse(data['adminShare']?.toString() ?? '0') ?? (totalAmount / 2);
              Timestamp? verifiedAt = data['verifiedAt'];
              String dateStr = verifiedAt != null ? verifiedAt.toDate().toString().split('.').first : 'N/A';

              String userQuestion = data['questionText'] ?? data['question'] ?? 'No Question text.';
              String aiResponse = data['aiAnswer'] ?? data['aiResponse'] ?? data['response'] ?? '';
              String optionalText = (data['userRemarks'] ?? data['optionalNote'] ?? data['userFeedback'] ?? data['feedback'] ?? data['additionalNote'] ?? '').toString().trim();
              String transactionId = data['transactionId'] ?? data['tid'] ?? 'N/A';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: const Icon(Icons.verified, color: Colors.green),
                  ),
                  title: Text(
                    userName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Text(
                          "Scholar: $scholarName",
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Total: RS $totalAmount",
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "TID: $transactionId",
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                              Text("Verified On: $dateStr", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Scholar Share (50%): RS $scholarShare", style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("Admin Share (50%): RS $adminShare", style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 24),
                          const Text("Sawal / Question:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40), fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(userQuestion, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, height: 1.4)),
                          const SizedBox(height: 16),
                          if (aiResponse.isNotEmpty) ...[
                            _buildResponseBox(title: "AI Response / Jawab:", message: aiResponse, icon: Icons.auto_awesome, themeColor: Colors.blue, isDark: isDark),
                            const SizedBox(height: 16),
                          ],
                          if (optionalText.isNotEmpty && optionalText != 'null') ...[
                            _buildResponseBox(title: "User's Additional Note / Remarks:", message: optionalText, icon: Icons.rate_review_outlined, themeColor: Colors.purple, isDark: isDark),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.receipt_long_outlined, size: 18),
                              label: const Text("Check Payment Receipt"),
                              onPressed: () => _showPaymentReceiptBottomSheet(context, data),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResponseBox({required String title, required String message, required IconData icon, required Color themeColor, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: themeColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: themeColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
        ],
      ),
    );
  }

  void _showPaymentReceiptBottomSheet(BuildContext context, Map<String, dynamic> data) {
    String? screenshotUrl = data['paymentProofUrl'] ?? data['paymentScreenshot'] ?? data['screenshot'] ?? data['screenshotUrl'];
    String amountPaid = data['amountPaid']?.toString() ?? data['totalAmount']?.toString() ?? '100';
    final double screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        margin: EdgeInsets.only(top: screenHeight * 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Payment Receipt", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Text("Amount: RS $amountPaid", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: (screenshotUrl != null && screenshotUrl.isNotEmpty)
                      ? Image.network(
                    screenshotUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(child: Text("Error loading image")),
                  )
                      : const Center(child: Text("No screenshot attached.")),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}