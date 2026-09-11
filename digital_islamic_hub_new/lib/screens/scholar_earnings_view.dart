import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class ScholarEarningsView extends StatelessWidget {
  final String scholarId;
  const ScholarEarningsView({super.key, required this.scholarId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Earnings & Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('scholar_earnings_ledger')
            .where('scholarId', isEqualTo: scholarId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }

          var docs = snapshot.data!.docs;

          double totalBalance = 0.0;
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            totalBalance += (data['amount'] ?? 0.0) as double;
          }

          bool canWithdraw = false;
          if (docs.isNotEmpty) {
            Timestamp firstEntryTime = docs.first['createdAt'] ?? Timestamp.now();
            DateTime date = firstEntryTime.toDate();
            if (DateTime.now().difference(date).inDays >= 7) {
              canWithdraw = true;
            }
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Accumulated Balance", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text("RS $totalBalance", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canWithdraw ? AppTheme.accentGreen : Colors.grey,
                        foregroundColor: isDark ? AppTheme.primaryDark : Colors.white,
                      ),
                      onPressed: canWithdraw ? () {
                        // Withdraw Logic
                      } : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Withdrawal locked! Funds can only be withdrawn after 1 week.")),
                        );
                      },
                      child: Text(canWithdraw ? "Withdraw" : "Locked (1 Week)"),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Earnings History", 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.primaryLight
                    )
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    double amount = data['amount'] ?? 0.0;
                    Timestamp? t = data['createdAt'];
                    String dateStr = t != null ? t.toDate().toString().split('.').first : '';

                    return Card(
                      color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDark ? AppTheme.accentGreen.withAlpha(40) : AppTheme.primaryLight.withAlpha(15),
                          child: Icon(Icons.arrow_downward, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                        ),
                        title: Text(
                          "Question Resolution Share", 
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)
                        ),
                        subtitle: Text("Credited on: $dateStr", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                        trailing: Text("+ RS $amount", style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
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