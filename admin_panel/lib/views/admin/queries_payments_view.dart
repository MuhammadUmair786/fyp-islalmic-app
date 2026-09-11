import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_payment_history_view.dart';

class QueriesPaymentsView extends StatefulWidget {
  const QueriesPaymentsView({super.key});

  @override
  State<QueriesPaymentsView> createState() => _QueriesPaymentsViewState();
}

class _QueriesPaymentsViewState extends State<QueriesPaymentsView> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text('Incoming Queries & Verification', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.payments_rounded, size: 26),
            tooltip: "Payment History",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPaymentHistoryView(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_questions')
            .where('status', isEqualTo: 'pending_verification')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "Alhamdulillah! No pending queries to verify right now.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktopOrWeb = constraints.maxWidth > 768;
              double horizontalPadding = isDesktopOrWeb ? 32.0 : 16.0;

              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String questionId = doc.id;

                      String userQuestion = data['questionText'] ?? data['question'] ?? 'No Question text.';
                      String aiResponse = data['aiAnswer'] ?? data['aiResponse'] ?? data['response'] ?? '';
                      String optionalText = (data['userRemarks'] ?? data['optionalNote'] ?? data['userFeedback'] ?? data['feedback'] ?? data['additionalNote'] ?? '').toString().trim();
                      String transactionId = data['transactionId'] ?? data['tid'] ?? 'N/A';

                      String? scholarId = data['scholarId'] ?? data['assignedScholarId'];
                      String? userId = data['userId'];

                      // User ki enter ki hui actual amount yahan fetch ho rahi hai
                      String amountPaid = data['amountPaid']?.toString() ?? data['feeAmount']?.toString() ?? '100';

                      return FutureBuilder<DocumentSnapshot>(
                        future: userId != null ? FirebaseFirestore.instance.collection('users').doc(userId).get() : Future.value(null),
                        builder: (context, userSnapshot) {
                          String userName = "User";
                          if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                            var uData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            userName = uData?['displayName'] ?? uData?['name'] ?? uData?['fullName'] ?? data['userName'] ?? 'User';
                          } else if (data['userName'] != null) {
                            userName = data['userName'];
                          }

                          return FutureBuilder<DocumentSnapshot>(
                            future: scholarId != null ? FirebaseFirestore.instance.collection('users').doc(scholarId).get() : Future.value(null),
                            builder: (context, scholarSnapshot) {
                              String requestedScholarName = "Assigned Scholar";
                              if (scholarSnapshot.hasData && scholarSnapshot.data != null && scholarSnapshot.data!.exists) {
                                var sData = scholarSnapshot.data!.data() as Map<String, dynamic>?;
                                requestedScholarName = sData?['displayName'] ?? sData?['name'] ?? sData?['fullName'] ?? data['scholarName'] ?? 'Assigned Scholar';
                              } else if (data['scholarName'] != null) {
                                requestedScholarName = data['scholarName'];
                              }

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
                                    backgroundColor: const Color(0xFF004D40).withOpacity(0.1),
                                    child: const Icon(Icons.person, color: Color(0xFF004D40)),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "New Question",
                                            style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Admin ko user ki bheji hui exact amount (e.g. Paid: RS 300) nazar aayegi
                                        Text(
                                          "Paid: RS $amountPaid",
                                          style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.all(isDesktopOrWeb ? 24.0 : 16.0),
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
                                              Text("Doc ID: $questionId", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                            ],
                                          ),
                                          const Divider(height: 24),
                                          const Text("Sawal / Question:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40), fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Text(userQuestion, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, height: 1.4, fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 16),
                                          if (aiResponse.isNotEmpty) ...[
                                            ResponseDisplayBox(title: "AI Response / Jawab:", message: aiResponse, icon: Icons.auto_awesome, themeColor: Colors.blue, isDark: isDark),
                                            const SizedBox(height: 16),
                                          ],
                                          if (optionalText.isNotEmpty && optionalText != 'null') ...[
                                            ResponseDisplayBox(title: "User's Optional Note / Remarks:", message: optionalText, icon: Icons.rate_review_outlined, themeColor: Colors.purple, isDark: isDark),
                                            const SizedBox(height: 16),
                                          ],
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(color: const Color(0xFF004D40).withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF004D40).withOpacity(0.15))),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.person_pin_rounded, color: Color(0xFF004D40), size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                                      children: [
                                                        const TextSpan(text: "Target Scholar Requested by User: "),
                                                        TextSpan(text: requestedScholarName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 32),
                                          _buildResponsiveActionControls(
                                              isDesktopOrWeb: isDesktopOrWeb,
                                              questionId: questionId,
                                              scholarId: scholarId,
                                              scholarName: requestedScholarName,
                                              data: data
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
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildResponsiveActionControls({required bool isDesktopOrWeb, required String questionId, required String? scholarId, required String scholarName, required Map<String, dynamic> data}) {
    Widget checkPaymentBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.receipt_long_outlined, size: 20),
      label: const Text("Check Payment Receipt"),
      onPressed: () => _showPaymentReceiptBottomSheet(context, data),
    );

    Widget verifyAndForwardBtn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.verified_user_rounded, size: 18),
      label: Text("Verify & Forward to $scholarName"),
      // Direct click par baghair kisi popup ke user ki amount ka half calculate ho kar forward ho jaye ga
      onPressed: () => _processVerificationDirectly(questionId, scholarId, scholarName, data),
    );

    if (isDesktopOrWeb) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [checkPaymentBtn, const SizedBox(width: 16), const Spacer(), verifyAndForwardBtn]);
    } else {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [checkPaymentBtn, const SizedBox(height: 12), verifyAndForwardBtn]);
    }
  }

  // 👈 Direct verification aur user ki amount ka half calculation
  Future<void> _processVerificationDirectly(String questionId, String? scholarId, String scholarName, Map<String, dynamic> data) async {
    // User ne jo amount enter ki thi (e.g., 300), usay yahan read kia ja raha hai
    double totalPaid = double.tryParse(data['amountPaid']?.toString() ?? data['feeAmount']?.toString() ?? '100') ?? 100.0;

    // Automatically half calculate karna (e.g., 300 ka 150)
    double adminShare = totalPaid / 2;
    double scholarShare = totalPaid / 2;

    await FirebaseFirestore.instance.collection('user_questions').doc(questionId).update({
      'status': 'sent_to_scholar',
      'verifiedAt': FieldValue.serverTimestamp(),
      'totalAmount': totalPaid,
      'adminShare': adminShare,
      'scholarShare': scholarShare,
    });

    if (scholarId != null && scholarId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('scholar_earnings_ledger').add({
        'scholarId': scholarId,
        'scholarName': scholarName,
        'questionId': questionId,
        'amount': scholarShare, // Yeh half amount scholar ke ledger mein save hogi realtime mein
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'accumulated',
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'scholarId': scholarId,
        'questionId': questionId,
        'targetRole': 'scholar',
        'title': 'New Question Received! 📩',
        'message': 'You have received a new verified question. RS $scholarShare has been added to your pending earnings ledger.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (data['userId'] != null) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'targetId': data['userId'],
        'questionId': questionId,
        'targetRole': 'user',
        'title': 'Question Submitted Successfully! ✅',
        'message': 'Your payment is verified and your question has been sent to the scholar.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verified! RS $scholarShare (Half of RS $totalPaid) allocated to scholar's ledger."))
      );
    }
  }

  void _showPaymentReceiptBottomSheet(BuildContext context, Map<String, dynamic> data) {
    String? screenshotUrl = data['paymentProofUrl'] ?? data['paymentScreenshot'] ?? data['screenshot'] ?? data['screenshotUrl'];
    String amountPaid = data['amountPaid']?.toString() ?? data['feeAmount']?.toString() ?? '100';
    final double screenHeight = MediaQuery.of(context).size.height;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))
          ),
          padding: const EdgeInsets.all(24),
          margin: EdgeInsets.only(top: screenHeight * 0.15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Payment Receipt", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
            const SizedBox(height: 16),
            Text("Amount Sent by User: RS $amountPaid", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(20)),
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
          ]),
        )
    );
  }
}

class ResponseDisplayBox extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color themeColor;
  final bool isDark;
  const ResponseDisplayBox({super.key, required this.title, required this.message, required this.icon, required this.themeColor, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: themeColor.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: themeColor.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: themeColor, size: 18), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeColor, fontSize: 13))]), const SizedBox(height: 8), Text(message, style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4))]));
  }
}