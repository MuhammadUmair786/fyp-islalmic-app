import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:digital_islamic_hub_new/screens/scholar_questions_screen.dart';
import 'package:digital_islamic_hub_new/screens/scholar_payments_screen.dart';
import 'package:digital_islamic_hub_new/screens/scholar_profile_screen.dart';
import 'scholar_notification_screen.dart';
import '../theme/app_theme.dart';

class ScholarDashboard extends StatefulWidget {
  const ScholarDashboard({super.key});

  @override
  State<ScholarDashboard> createState() => _ScholarDashboardState();
}

class _ScholarDashboardState extends State<ScholarDashboard> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('scholars').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        String userName = user?.displayName ?? "Scholar";
        String? profileImageUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            userName = data['displayName'] ?? user?.displayName ?? "Scholar";
            profileImageUrl = data['profileImage'];
          }
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
            title: const Text("Scholar Portal", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            centerTitle: true,
            actions: [
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('scholarId', isEqualTo: user?.uid)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, notifSnapshot) {
                  int unreadCount = 0;
                  if (notifSnapshot.hasData) {
                    unreadCount = notifSnapshot.data!.docs.length;
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications_active_outlined,
                          size: 26,
                          color: unreadCount > 0 ? AppTheme.accentGreen : Colors.white,
                        ),
                        tooltip: "Notifications",
                        onPressed: () {
                          if (user != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScholarNotificationsScreen(
                                  currentScholarId: user!.uid,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white24,
                    backgroundImage: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                        ? NetworkImage(profileImageUrl) as ImageProvider
                        : null,
                    child: (profileImageUrl == null || profileImageUrl.isEmpty)
                        ? const Icon(Icons.person_outline_rounded, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                tooltip: "Profile",
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScholarProfileScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Assalamu Alaikum,", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(userName, style: TextStyle(color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 26)),
                  const SizedBox(height: 30),

                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: _DashboardCard(
                                title: "Consultation Inquiries",
                                icon: Icons.chat_bubble_rounded,
                                color: Colors.orange,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScholarQuestionsScreen(scholarId: user!.uid))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: _DashboardCard(
                                title: "Wallet & Earnings",
                                icon: Icons.account_balance_wallet_rounded,
                                color: Colors.blue,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScholarPaymentsScreen(scholarId: user!.uid))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(15) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 3))],
          border: Border.all(color: isDark ? Colors.white10 : AppTheme.primaryLight.withAlpha(30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}