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
              _buildNotificationIcon(user?.uid, isDark),
              _buildProfileIcon(profileImageUrl, isDark),
              const SizedBox(width: 10),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Assalamu Alaikum,", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(userName, style: TextStyle(color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 28)),
                  const SizedBox(height: 40),
                  
                  _DashboardTile(
                    title: "Consultation Inquiries",
                    subtitle: "Manage and answer user queries",
                    icon: Icons.forum_rounded,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScholarQuestionsScreen(scholarId: user!.uid))),
                  ),
                  const SizedBox(height: 18),
                  _DashboardTile(
                    title: "Wallet & Earnings",
                    subtitle: "Track your consultation revenue",
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.blueAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScholarPaymentsScreen(scholarId: user!.uid))),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationIcon(String? uid, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').where('scholarId', isEqualTo: uid).where('isRead', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, size: 28, color: count > 0 ? AppTheme.accentGreen : Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ScholarNotificationsScreen(currentScholarId: uid ?? ""))),
            ),
            if (count > 0)
              Positioned(right: 10, top: 10, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
          ],
        );
      },
    );
  }

  Widget _buildProfileIcon(String? url, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScholarProfileScreen())),
      child: Container(
        margin: const EdgeInsets.only(left: 5),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 1.5)),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white10,
          backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
          child: (url == null || url.isEmpty) ? const Icon(Icons.person, size: 18, color: Colors.white) : null,
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(12) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 15, offset: const Offset(0, 8))],
          border: Border.all(color: isDark ? Colors.white10 : AppTheme.primaryLight.withAlpha(15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.white24 : Colors.grey.shade300),
          ],
        ),
      ),
    );
  }
}
