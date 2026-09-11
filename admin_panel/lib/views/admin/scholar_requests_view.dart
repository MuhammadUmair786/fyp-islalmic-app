import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// =========================================================================
// 🏛️ 1. MAIN VIEW SCREEN (ScholarRequestsView)
// =========================================================================
class ScholarRequestsView extends StatelessWidget {
  const ScholarRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 750;
    final double contentWidth = isDesktop ? 700 : screenWidth;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        // 🔢 LIVE COUNTER: AppBar mein hi pending requests ki ginti show ho gi
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('scholars')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text("Scholar Requests ${count > 0 ? '($count)' : ''}");
          },
        ),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'history') {
                _showHistoryDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, color: Colors.black54),
                    SizedBox(width: 8),
                    Text("Verification History"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SizedBox(
          width: contentWidth,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('scholars')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
              }

              final requests = snapshot.data?.docs ?? [];

              // 🔄 CLIENT-SIDE SORTING: Nayi request ko automatically top par laane ke liye
              requests.sort((a, b) {
                var aData = a.data() as Map<String, dynamic>;
                var bData = b.data() as Map<String, dynamic>;

                Timestamp? aTime = aData['createdAt'] as Timestamp?;
                Timestamp? bTime = bData['createdAt'] as Timestamp?;

                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime); // descending order (newest first)
              });

              if (requests.isEmpty) {
                return _buildEmptyState(
                  title: "No pending requests found!",
                  subtitle: "There are currently no scholars waiting for verification.",
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  var data = requests[index].data() as Map<String, dynamic>;
                  return ScholarCard(data: data, docId: requests[index].id, isHistoryCard: false);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) => Center(child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Text("Error: $error", style: const TextStyle(color: Colors.red)),
  ));

  Widget _buildEmptyState({required String title, required String subtitle}) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    ),
  );

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: 700,
            height: MediaQuery.of(context).size.height * 0.8,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: Color(0xFF004D40),
                    labelColor: Color(0xFF004D40),
                    tabs: [Tab(text: "Approved"), Tab(text: "Rejected")],
                  ),
                  Expanded(
                    child: TabBarView(children: [
                      _buildHistoryTabStream(statusFilter: 'approved'),
                      _buildHistoryTabStream(statusFilter: 'rejected'),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTabStream({required String statusFilter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('scholars')
          .where('status', isEqualTo: statusFilter)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text("No $statusFilter requests found."));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) => ScholarCard(
            data: docs[index].data() as Map<String, dynamic>,
            docId: docs[index].id,
            isHistoryCard: true,
          ),
        );
      },
    );
  }
}

// =========================================================================
// 🛠️ 2. SCHOLAR CARD WITH FULL DETAILS, IMAGE & ACTIONS (Approve/Reject)
// =========================================================================
class ScholarCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isHistoryCard;

  const ScholarCard({super.key, required this.data, required this.docId, required this.isHistoryCard});

  @override
  Widget build(BuildContext context) {
    String? storageImageUrl = data['image'];

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and Email
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                data['displayName'] ?? 'Scholar',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text(data['email'] ?? ''),
              trailing: !isHistoryCard
                  ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(6)),
                child: const Text("New", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              )
                  : null,
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Scholar Details
            _buildDetailRow("Phone:", data['phone'] ?? 'N/A'),
            _buildDetailRow("Degree:", data['degree'] ?? 'N/A'),
            _buildDetailRow("Address:", data['address'] ?? 'N/A'),
            _buildDetailRow("Gender:", data['gender'] ?? 'N/A'),
            _buildDetailRow("Certificate:", data['payment_method'] ?? 'N/A'),

            const SizedBox(height: 12),

            // --- IMAGE LOADING SECTION ---
            if (storageImageUrl != null && storageImageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text("Degree / Certificate Screenshot:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Image.network(
                      storageImageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text("Image not available"));
                      },
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Area (Approve & Reject Buttons)
            if (!isHistoryCard)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Reject Button
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _updateScholarStatus(context, docId, data['displayName'] ?? 'Scholar', 'rejected', data['email']),
                    child: const Text("Reject"),
                  ),
                  const SizedBox(width: 12),
                  // Approve Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _updateScholarStatus(context, docId, data['displayName'] ?? 'Scholar', 'approved', data['email']),
                    child: const Text("Approve"),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  // Helper widget to display text rows neatly
  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  void _updateScholarStatus(BuildContext context, String docId, String name, String status, String? scholarEmail) async {
    // 1. Firestore status update
    await FirebaseFirestore.instance.collection('scholars').doc(docId).update({'status': status});

    // 2. 📧 Send Email via Firebase 'mail' collection (Trigger Email Extension)
    if (scholarEmail != null && scholarEmail.isNotEmpty) {
      String subject = status == 'approved'
          ? 'Congratulations! Your Scholar Account is Approved 🎉'
          : 'Scholar Account Verification Update';

      String bodyText = status == 'approved'
          ? 'Alhamdulillah $name! Aap ka scholar account approve ho chuka hai. Aap ab app mein login karke sawalon ke jawabat de sakte hain.'
          : 'Badqismati se aap ki scholar request filhal reject kar di gayi hai. Mazeed maloomat ke liye admin se rabta karein.';

      await FirebaseFirestore.instance.collection('mail').add({
        'to': scholarEmail,
        'message': {
          'subject': subject,
          'text': bodyText,
        },
      });
    }

    String message = status == 'approved' ? "$name approved successfully!" : "$name request rejected!";
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}