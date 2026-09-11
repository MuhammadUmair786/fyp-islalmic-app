import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:admin/view_models/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'cloudinary_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

class ScholarAnswerView extends StatelessWidget {
  const ScholarAnswerView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("Scholar Weekly Payouts"),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_questions')
            .where('status', isEqualTo: 'answered')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No answered questions are available"),
            );
          }

          var docs = snapshot.data!.docs;

          docs.sort((a, b) {
            Timestamp? timeA = (a.data() as Map<String, dynamic>)['answeredAt'] ?? (a.data() as Map<String, dynamic>)['createdAt'];
            Timestamp? timeB = (b.data() as Map<String, dynamic>)['answeredAt'] ?? (b.data() as Map<String, dynamic>)['createdAt'];
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA);
          });

          Map<String, List<Map<String, dynamic>>> scholarGroups = {};
          Map<String, String> scholarPhones = {};

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            data['docId'] = doc.id;

            String scholarName = data['scholarName'] ?? 'Unknown Scholar';
            String scholarPhone = data['scholarPhone'] ?? 'Number number not available';

            if (!scholarGroups.containsKey(scholarName)) {
              scholarGroups[scholarName] = [];
            }
            scholarGroups[scholarName]!.add(data);
            scholarPhones[scholarName] = scholarPhone;
          }

          if (scholarGroups.isEmpty) {
            return const Center(
              child: Text(
                "No data available for any scholars.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            );
          }

          var scholarKeys = scholarGroups.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scholarKeys.length,
            itemBuilder: (context, index) {
              String scholarName = scholarKeys[index];
              var questionsList = scholarGroups[scholarName]!;
              String scholarPhone = scholarPhones[scholarName] ?? '';

              double totalWeeklyAmount = 0;
              for (var q in questionsList) {
                bool isPaid = q['isPaidToScholar'] ?? false;
                if (!isPaid) {
                  double share = double.tryParse(q['scholarShare']?.toString() ?? q['amount']?.toString() ?? '0') ?? 0;
                  totalWeeklyAmount += share;
                }
              }

              bool isWeekCompleted = false;
              for (var q in questionsList) {
                bool isPaid = q['isPaidToScholar'] ?? false;
                if (!isPaid) {
                  Timestamp? t = q['answeredAt'] ?? q['createdAt'];
                  if (t != null) {
                    DateTime date = t.toDate();
                    if (DateTime.now().difference(date).inDays >= 7) {
                      isWeekCompleted = true;
                      break;
                    }
                  }
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scholarName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.tealAccent : const Color(0xFF004D40),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Account / Number: $scholarPhone",
                                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: totalWeeklyAmount > 0 ? Colors.red.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: totalWeeklyAmount > 0 ? Colors.red : Colors.green, width: 1.5),
                            ),
                            child: Text(
                              "RS ${totalWeeklyAmount.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: totalWeeklyAmount > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Total Answer Record: ${questionsList.length}",
                            style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: totalWeeklyAmount == 0 ? Colors.grey : (isWeekCompleted ? Colors.red : Colors.green),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScholarWithdrawalFullScreen(
                                    scholarName: scholarName,
                                    questionsList: questionsList,
                                    isDark: isDark,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text("View Full Details", style: TextStyle(fontWeight: FontWeight.bold)),
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

// 📱 FULL SCREEN DETAILS PAGE
class ScholarWithdrawalFullScreen extends StatefulWidget {
  final String scholarName;
  final List<Map<String, dynamic>> questionsList;
  final bool isDark;

  const ScholarWithdrawalFullScreen({
    super.key,
    required this.scholarName,
    required this.questionsList,
    required this.isDark,
  });

  @override
  State<ScholarWithdrawalFullScreen> createState() => _ScholarWithdrawalFullScreenState();
}

class _ScholarWithdrawalFullScreenState extends State<ScholarWithdrawalFullScreen> {
  @override
  Widget build(BuildContext context) {
    double completedWeekAmount = 0;
    double runningWeekAmount = 0;
    List<Map<String, dynamic>> completedQuestions = [];

    for (var q in widget.questionsList) {
      bool isPaid = q['isPaidToScholar'] ?? false;
      if (isPaid) continue;

      double share = double.tryParse(q['scholarShare']?.toString() ?? q['amount']?.toString() ?? '0') ?? 0;
      Timestamp? t = q['answeredAt'] ?? q['createdAt'];

      if (t != null) {
        DateTime date = t.toDate();
        int differenceDays = DateTime.now().difference(date).inDays;

        if (differenceDays >= 7) {
          completedWeekAmount += share;
          completedQuestions.add(q);
        } else {
          runningWeekAmount += share;
        }
      } else {
        runningWeekAmount += share;
      }
    }

    bool isWeekCompleted = completedWeekAmount > 0;
    double displayAmount = isWeekCompleted ? completedWeekAmount : runningWeekAmount;
    List<Map<String, dynamic>> targetQuestions = isWeekCompleted ? completedQuestions : widget.questionsList;

    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text("Payout Details: ${widget.scholarName}"),
        backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: widget.isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.teal),
            tooltip: "Payment Screenshots & History",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScholarPaymentHistoryScreen(
                    scholarName: widget.scholarName,
                    questionsList: widget.questionsList,
                    isDark: widget.isDark,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayAmount == 0 ? "All Cleared:" : (isWeekCompleted ? "Completed Week Payout:" : "Running Week Balance:"),
                        style: TextStyle(
                          fontSize: 12,
                          color: displayAmount == 0 ? Colors.grey : (isWeekCompleted ? Colors.red : Colors.green),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "RS ${displayAmount.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: displayAmount == 0 ? Colors.grey : (isWeekCompleted ? Colors.red : Colors.green),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayAmount == 0 ? "No Pending Amount." : (isWeekCompleted ? "7 days completed. Ready to pay!" : "Running week balance (Manual Payout)"),
                        style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (displayAmount > 0)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isWeekCompleted ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentSubmitFullScreen(
                              scholarName: widget.scholarName,
                              totalAmount: displayAmount,
                              questionsList: targetQuestions.isNotEmpty ? targetQuestions : widget.questionsList,
                              isDark: widget.isDark,
                            ),
                          ),
                        );
                      },
                      icon: Icon(isWeekCompleted ? Icons.payment : Icons.lock_open, size: 18),
                      label: Text(
                        isWeekCompleted ? "Withdraw / Pay" : "Process Payout",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text("Scholar Answers & Questions Record:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.questionsList.length,
              itemBuilder: (context, index) {
                var q = widget.questionsList[index];

                String questionText = q['questionText'] ?? q['question'] ?? q['question_text'] ?? 'No Question';
                String additionalNote = q['Additional Note / Message'] ?? q['additionalNote'] ?? q['userAdditionalNote'] ?? '';
                String aiAnswerText = q['aiResponse'] ?? q['aiAnswer'] ?? 'No AI Answer';
                String scholarAnswerText = q['scholarResponse'] ?? q['answer'] ?? 'No Scholar Answer Yet';
                String amount = q['scholarShare']?.toString() ?? q['amount']?.toString() ?? '0';
                bool isPaid = q['isPaidToScholar'] ?? false;

                Timestamp? answeredAt = q['answeredAt'] as Timestamp?;
                String formattedDate = "N/A";
                String timeStatusText = "";
                Color timeStatusColor = Colors.grey;

                if (answeredAt != null) {
                  DateTime dateTime = answeredAt.toDate();
                  formattedDate = DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(dateTime);

                  int daysPassed = DateTime.now().difference(dateTime).inDays;
                  int daysLeft = 7 - daysPassed;

                  if (isPaid) {
                    timeStatusText = "Paid";
                    timeStatusColor = Colors.green;
                  } else if (daysPassed >= 7) {
                    timeStatusText = "7 days completed. Ready to pay!";
                    timeStatusColor = Colors.red;
                  } else {
                    timeStatusText = daysLeft == 1 ? "1 day left" : "$daysLeft days left";
                    timeStatusColor = Colors.orange;
                  }
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  formattedDate,
                                  style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: timeStatusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: timeStatusColor, width: 1),
                                  ),
                                  child: Text(
                                    timeStatusText,
                                    style: TextStyle(color: timeStatusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text("RS $amount", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.blue.withAlpha(20) : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withAlpha(70)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("User Question", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                              const SizedBox(height: 4),
                              Text(questionText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (additionalNote.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isDark ? Colors.purple.withAlpha(20) : Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.withAlpha(70)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Additional Note / Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                                const SizedBox(height: 4),
                                Text(additionalNote, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white70 : Colors.black87)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.orange.withAlpha(20) : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withAlpha(70)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("AI Answer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                              const SizedBox(height: 4),
                              Text(aiAnswerText, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.white70 : Colors.black87)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark ? Colors.green.withAlpha(20) : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withAlpha(70)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Scholar Answer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                                    const SizedBox(height: 4),
                                    Text(scholarAnswerText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: widget.isDark ? Colors.greenAccent : const Color(0xFF2E7D32))),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (!isPaid)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PaymentSubmitFullScreen(
                                          scholarName: widget.scholarName,
                                          totalAmount: double.tryParse(amount) ?? 50.0,
                                          questionsList: [q],
                                          isDark: widget.isDark,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.send, size: 14),
                                  label: const Text("Pay", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 📂 SCREEN: SCHOLAR PAYMENT HISTORY & SCREENSHOTS
class ScholarPaymentHistoryScreen extends StatelessWidget {
  final String scholarName;
  final List<Map<String, dynamic>> questionsList;
  final bool isDark;

  const ScholarPaymentHistoryScreen({
    super.key,
    required this.scholarName,
    required this.questionsList,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    var paidQuestions = questionsList.where((q) {
      bool isPaid = q['isPaidToScholar'] ?? false;
      String screenshot = q['paymentScreenshot'] ?? '';
      return isPaid && screenshot.isNotEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text("Payment History: $scholarName"),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: paidQuestions.isEmpty
          ? const Center(
        child: Text(
          "Abhi tak is scholar ko koi payment nahi ki gayi ya screenshot mojood nahi hai.",
          style: TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paidQuestions.length,
        itemBuilder: (context, index) {
          var q = paidQuestions[index];
          String transactionId = q['transactionId'] ?? 'N/A';
          String paidAmount = q['paidAmount']?.toString() ?? '0';
          String screenshotUrl = q['paymentScreenshot'] ?? '';
          Timestamp? paidAt = q['paidAt'] as Timestamp?;

          String formattedDateTime = "N/A";
          if (paidAt != null) {
            DateTime dt = paidAt.toDate();
            formattedDateTime = DateFormat('EEEE, dd MMM yyyy, hh:mm a').format(dt);
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Paid Amount: RS $paidAmount",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("Success", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Transaction ID: $transactionId",
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(
                        "Paid On: $formattedDateTime",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.tealAccent : Colors.teal[800]),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Text("Payment Screenshot:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      screenshotUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Text("Could not load image")),
                      ),
                    ),
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

// 💳 PAYMENT SUBMIT SCREEN
class PaymentSubmitFullScreen extends StatefulWidget {
  final String scholarName;
  final double totalAmount;
  final List<Map<String, dynamic>> questionsList;
  final bool isDark;

  const PaymentSubmitFullScreen({
    super.key,
    required this.scholarName,
    required this.totalAmount,
    required this.questionsList,
    required this.isDark,
  });

  @override
  State<PaymentSubmitFullScreen> createState() => _PaymentSubmitFullScreenState();
}

class _PaymentSubmitFullScreenState extends State<PaymentSubmitFullScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();

  bool _isSubmitting = false;
  String? _uploadedImageUrl;
  String _liveTimeText = "";

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.totalAmount.toStringAsFixed(0);
    _liveTimeText = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isSubmitting = true;
      });

      final cloudinary = CloudinaryPublic('lxuuhill', 'AppPresent', cache: false);
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          folder: 'scholar_payouts',
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      setState(() {
        _uploadedImageUrl = response.secureUrl;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading image: $e")),
      );
    }
  }

  Future<void> _submitPaymentRecord() async {
    if (_transactionIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Transaction ID")),
      );
      return;
    }
    if (_uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload payment screenshot")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var q in widget.questionsList) {
        String docId = q['docId'];
        DocumentReference documentRef = FirebaseFirestore.instance.collection('user_questions').doc(docId);

        batch.update(documentRef, {
          'isPaidToScholar': true,
          'paidAmount': double.tryParse(_amountController.text) ?? widget.totalAmount,
          'transactionId': _transactionIdController.text.trim(),
          'paymentScreenshot': _uploadedImageUrl,
          'paidAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment successfully recorded!")),
      );
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit payment: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text("Submit Payment: ${widget.scholarName}"),
        backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: widget.isDark ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Amount to Pay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: "RS ",
              ),
            ),
            const SizedBox(height: 16),
            const Text("Transaction ID / Reference Number", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _transactionIdController,
              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: "Enter transaction id",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Payment Screenshot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: Center(
                  child: _isSubmitting && _uploadedImageUrl == null
                      ? const CircularProgressIndicator()
                      : _uploadedImageUrl != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_uploadedImageUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_upload, size: 40, color: Colors.teal),
                      SizedBox(height: 8),
                      Text("Click to upload payment screenshot", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text("Time: $_liveTimeText", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSubmitting ? null : _submitPaymentRecord,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Confirm & Submit Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}