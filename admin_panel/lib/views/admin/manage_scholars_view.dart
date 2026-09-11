import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageScholarsPage extends StatelessWidget {
  const ManageScholarsPage({Key? key}) : super(key: key);

  // 📈 Dynamic Stream: Scholars ke status ke mutabik accurate counting
  Stream<int> getScholarCount({String? statusValue}) {
    return FirebaseFirestore.instance.collection('scholars').snapshots().map((snapshot) {
      if (statusValue == 'blocked') {
        return snapshot.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'blocked';
        }).length;
      } else if (statusValue == 'active') {
        return snapshot.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'blocked';
        }).length;
      } else {
        return snapshot.docs.length;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Scholars"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Scholar Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 20),
            Row(
              children: [
                _counterCard(context, "Total Scholars", getScholarCount(), Colors.blue, Icons.school_outlined),
                const SizedBox(width: 16),
                _counterCard(context, "Active", getScholarCount(statusValue: 'active'), Colors.green, Icons.check_circle_outline),
                const SizedBox(width: 16),
                _counterCard(context, "Blocked", getScholarCount(statusValue: 'blocked'), Colors.red, Icons.block_outlined),
              ],
            ),
            const SizedBox(height: 40),
            Text("Verified Scholar List", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 20),
            _buildVerifiedScholarsList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedScholarsList(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('scholars').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No verified scholars found.", style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var scholar = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;
            bool isBlocked = scholar['status'] == 'blocked';
            String scholarEmail = scholar['email'] ?? 'No Email';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              // CardTheme in main.dart handles colors
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: isBlocked ? Colors.red.withOpacity(0.1) : theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.school, color: isBlocked ? Colors.red : theme.colorScheme.primary),
                  ),
                  title: Text(
                    scholarEmail,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isBlocked ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('scholars').doc(docId).update({
                          'status': isBlocked ? 'active' : 'blocked',
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBlocked ? Colors.green : Colors.red,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        isBlocked ? "Unblock" : "Block",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _counterCard(BuildContext context, String title, Stream<int> stream, Color color, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border(left: BorderSide(color: color, width: 5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                  Text(
                    snapshot.data?.toString() ?? '0',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
