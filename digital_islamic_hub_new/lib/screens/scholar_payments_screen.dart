import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class ScholarPaymentsScreen extends StatefulWidget {
  final String scholarId;

  const ScholarPaymentsScreen({super.key, required this.scholarId});

  @override
  State<ScholarPaymentsScreen> createState() => _ScholarPaymentsScreenState();
}

class _ScholarPaymentsScreenState extends State<ScholarPaymentsScreen> {

  void _processItemWithdrawal(BuildContext context, String docId, double amount, String scholarName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
        title: Text("Confirm Subscription Payout", style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryLight)),
        content: Text("Do you want to request withdrawal for Rs. ${amount.toStringAsFixed(0)}?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
            onPressed: () async {
              Navigator.pop(ctx);

              try {
                await FirebaseFirestore.instance
                    .collection('user_questions')
                    .doc(docId)
                    .update({'status': 'processing'});

                await FirebaseFirestore.instance.collection('notifications').add({
                  'targetRole': 'admin',
                  'title': 'Subscription Withdrawal Request',
                  'message': 'Scholar $scholarName requested a withdrawal of Rs. ${amount.toStringAsFixed(0)}.',
                  'createdAt': FieldValue.serverTimestamp(),
                  'isRead': false,
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Withdrawal request sent to Admin successfully!"),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text("Confirm", style: TextStyle(color: isDark ? AppTheme.primaryDark : Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSingleReceiptPopup(BuildContext context, Map<String, dynamic> data, bool isDark) {
    String transactionId = data['transactionId'] ?? 'TRX-Pending / Not Provided';
    String imageUrl = data['paymentScreenshot'] ?? data['screenshot'] ?? data['receiptUrl'] ?? data['paymentProofUrl'] ?? '';
    double amount = double.tryParse(data['paidAmount']?.toString() ?? data['scholarShare']?.toString() ?? '50') ?? 50.0;

    Timestamp? paidTimestamp = data['paidAt'] as Timestamp? ?? data['answeredAt'] as Timestamp?;
    String formattedDayTime = "N/A";
    if (paidTimestamp != null) {
      formattedDayTime = DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(paidTimestamp.toDate());
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Subscription Receipt & Proof", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.primaryLight)),
            IconButton(
              icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Amount: RS ${amount.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : Colors.green, fontSize: 15)),
                const SizedBox(height: 8),
                Text("Transaction ID: $transactionId", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight)),
                const SizedBox(height: 4),
                Text("Date & Time: $formattedDayTime", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Divider(height: 20),
                const Text("Payment Screenshot / Proof:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                imageUrl.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Text("Failed to load image.", style: TextStyle(color: Colors.red)),
                    ),
                  ),
                )
                    : Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("No screenshot attached.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Scholar Earnings & Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_questions')
            .where('scholarId', isEqualTo: widget.scholarId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No subscription earnings found.",
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.grey),
              ),
            );
          }

          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String status = (data['status'] ?? 'answered').toString().toLowerCase();
            return status == 'answered' || status == 'processing' || status == 'paid';
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No earnings history found.",
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.grey),
              ),
            );
          }

          double totalEarnings = 0;
          double paidAmountTotal = 0;
          List<Map<String, dynamic>> paidQuestionsList = [];

          DateTime now = DateTime.now();

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            data['docId'] = doc.id;

            double amount = double.tryParse(data['scholarShare']?.toString() ?? data['amount']?.toString() ?? '50') ?? 50.0;
            totalEarnings += amount;

            bool isPaid = data['isPaidToScholar'] ?? false;
            if (isPaid) {
              paidAmountTotal += amount;
              paidQuestionsList.add(data);
            }
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark ? [AppTheme.primaryLight, AppTheme.primaryDark] : [AppTheme.primaryLight, const Color(0xFF00695C)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? [] : [
                    BoxShadow(
                      color: Colors.green.withAlpha(75),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Total Consultation Earnings",
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Rs. ${totalEarnings.toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Paid: Rs. ${paidAmountTotal.toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppTheme.accentGreen : Colors.white,
                        foregroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScholarPaymentDetailsScreen(
                              scholarId: widget.scholarId,
                              paidQuestions: paidQuestionsList.isNotEmpty
                                  ? paidQuestionsList
                                  : docs.map((e) => e.data() as Map<String, dynamic>).toList(),
                              isDark: isDark,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet, size: 16),
                      label: const Text(
                        "Cashout History",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String docId = docs[index].id;
                    double amount = double.tryParse(data['scholarShare']?.toString() ?? '50') ?? 50.0;
                    String userId = data['userId'] ?? 'unknown_user';
                    String itemStatus = (data['status'] ?? 'answered').toString().toLowerCase();

                    Timestamp? answeredTimestamp = data['answeredAt'] as Timestamp?;
                    DateTime answerDate = answeredTimestamp != null ? answeredTimestamp.toDate() : DateTime.now();

                    bool isPaid = data['isPaidToScholar'] ?? false;
                    bool is7DaysPassed = now.difference(answerDate).inDays >= 7;
                    bool isUnlocked = isPaid || is7DaysPassed;

                    String transactionId = data['transactionId'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        String displayName = "User";
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                          String? fetchedName = userData?['displayName'] ?? userData?['name'] ?? userData?['fullName'] ?? userData?['userName'];
                          if (fetchedName != null && fetchedName.isNotEmpty) {
                            displayName = fetchedName;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 14, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                                          const SizedBox(width: 4),
                                          Text(
                                            displayName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data['questionText'] ?? "Subscription Inquiry",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(answerDate),
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            "Rs. ${amount.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                                            ),
                                          ),
                                          if (isPaid) ...[
                                            const SizedBox(width: 10),
                                            InkWell(
                                              onTap: () => _showSingleReceiptPopup(context, data, isDark),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isDark ? AppTheme.accentGreen.withAlpha(20) : Colors.green.withAlpha(38),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: isDark ? AppTheme.accentGreen : Colors.green),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.receipt, size: 12, color: isDark ? AppTheme.accentGreen : Colors.green),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      transactionId.isNotEmpty ? "ID: $transactionId" : "Transferred",
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : Colors.green),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                isPaid
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.accentGreen.withAlpha(20) : Colors.green.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? AppTheme.accentGreen : Colors.green),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 14, color: isDark ? AppTheme.accentGreen : Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Paid",
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : Colors.green),
                                      ),
                                    ],
                                  ),
                                )
                                    : itemStatus == 'processing'
                                    ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withAlpha(38),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: const Text(
                                    "Processing",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                )
                                    : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isUnlocked ? AppTheme.accentGreen : Colors.grey.shade400,
                                    foregroundColor: isDark ? AppTheme.primaryDark : Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: isUnlocked ? () => _processItemWithdrawal(context, docId, amount, displayName) : null,
                                  icon: Icon(isUnlocked ? Icons.account_balance_wallet : Icons.lock, size: 14),
                                  label: Text(
                                    isUnlocked ? "Withdraw" : "Locked",
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ScholarPaymentDetailsScreen extends StatelessWidget {
  final String scholarId;
  final List<Map<String, dynamic>> paidQuestions;
  final bool isDark;

  const ScholarPaymentDetailsScreen({
    super.key,
    required this.scholarId,
    required this.paidQuestions,
    required this.isDark,
  });

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Payout History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: paidQuestions.isEmpty
          ? Center(
        child: Text(
          "No payment record found.",
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paidQuestions.length,
        itemBuilder: (context, index) {
          var item = paidQuestions[index];

          String transactionId = item['transactionId'] ?? 'TRX-Pending';
          String imageUrl = item['paymentScreenshot'] ?? item['screenshot'] ?? item['receiptUrl'] ?? item['paymentProofUrl'] ?? '';

          double amount = double.tryParse(item['paidAmount']?.toString() ?? item['scholarShare']?.toString() ?? '0') ?? 0;
          bool isPaid = item['isPaidToScholar'] ?? false;

          Timestamp? paidTimestamp = item['paidAt'] as Timestamp? ?? item['answeredAt'] as Timestamp?;
          String formattedDayTime = "N/A";
          if (paidTimestamp != null) {
            formattedDayTime = DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(paidTimestamp.toDate());
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: isDark ? 0 : 2,
            color: isDark ? Colors.white.withAlpha(10) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      if (imageUrl.isNotEmpty) {
                        _showImageDialog(context, imageUrl);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No screenshot attached.")),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isPaid ? Colors.green : Colors.orange).withAlpha(30),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isPaid ? Colors.green : Colors.orange),
                          ),
                          child: Row(
                            children: [
                              Icon(isPaid ? Icons.check_circle : Icons.hourglass_top, size: 12, color: isPaid ? Colors.green : Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                isPaid ? "Transferred" : "Pending",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.orange),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "RS ${amount.toStringAsFixed(0)}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.numbers, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Transaction ID:", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 1),
                            SelectableText(
                              transactionId,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time_filled, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Day & Time:", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 1),
                          Text(
                            formattedDayTime,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}