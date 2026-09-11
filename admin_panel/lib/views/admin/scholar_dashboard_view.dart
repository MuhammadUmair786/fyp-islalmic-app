import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:admin/view_models/theme_provider.dart';
import 'package:admin/view_models/profile_view_model.dart';
import 'admin_information_screen.dart';
import 'package:admin/views/admin/upload_books_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _listenToIncomingUserQuestions();
  }

  // 🚀 Admin Live Notification & Payment Listener
  void _listenToIncomingUserQuestions() {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('targetRole', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((QuerySnapshot snapshot) {

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          String notificationId = data['doc.id'] ?? change.doc.id;

          String title = data['title'] ?? 'New Notification';
          String message = data['message'] ?? 'Scholar ne jawab submit kar diya hai.';
          String userName = data['userName'] ?? 'Naye User';
          String amount = data['amountPaid'] ?? '0';

          // 1️⃣ SnackBar Alert
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("$title: $message"),
                backgroundColor: const Color(0xFF004D40),
                duration: const Duration(seconds: 4),
              ),
            );
          }

          // 2️⃣ Detailed Popup Dialog
          _showAdminLiveAlertDialog(userName, amount, notificationId);
        }
      }
    });
  }

  void _showAdminLiveAlertDialog(String userName, String amount, String notificationId) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.monetization_on, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text("New Payment & Question!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("User Name: $userName", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Amount Paid: RS $amount"),
              const SizedBox(height: 12),
              const Text("Naya sawal verification ke liye pending list mein add ho chuka hai.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
                  'isRead': true,
                });
              },
              child: const Text('OK', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
                  'isRead': true,
                });
              },
              child: const Text('Check Now', style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;

    int crossAxisCount = 1;
    double childAspectRatio = 2.8;

    if (screenWidth > 1400) {
      crossAxisCount = 3;
      childAspectRatio = 2.5;
    } else if (screenWidth > 950) {
      crossAxisCount = 2;
      childAspectRatio = 2.4;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
      childAspectRatio = 2.0;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 2.8;
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
      drawer: isMobile ? const Drawer(child: _Sidebar()) : null,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Row(
          children: [
            if (!isMobile) const _Sidebar(),
            Expanded(
              child: Column(
                children: [
                  _TopHeader(scaffoldKey: _scaffoldKey, isMobile: isMobile),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "Admin Control Panel",
                              style: TextStyle(fontSize: isMobile ? 22 : 28, fontWeight: FontWeight.bold)
                          ),
                          SizedBox(height: isMobile ? 20 : 32),

                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dashboardModulesConfig.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: isMobile ? 16 : 24,
                              mainAxisSpacing: isMobile ? 16 : 24,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemBuilder: (context, index) {
                              final module = dashboardModulesConfig[index];
                              return _ModuleCard(
                                title: module.title,
                                subtitle: module.subtitle,
                                icon: module.icon,
                                iconColor: module.iconColor,
                                backgroundColor: module.backgroundColor,
                                spacingAfter: module.spacingAfter,
                                onTap: () {
                                  // Route handling for Upload Books screen
                                  if (module.route == '/upload_books') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const UploadBooksView()),
                                    );
                                  } else {
                                    Navigator.pushNamed(context, module.route);
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final double spacingAfter;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.spacingAfter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: spacingAfter),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Align(
                  alignment: Alignment.center,
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();
  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final profileVM = Provider.of<ProfileViewModel>(context);
    return Container(
      width: 270,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Panel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.tealAccent : const Color(0xFF004D40))),
          const SizedBox(height: 40),
          _SidebarItem(icon: Icons.dashboard_outlined, label: 'Dashboard', isActive: true, onTap: () => Navigator.pushReplacementNamed(context, '/dashboard')),
          _SidebarItem(icon: Icons.library_books_outlined, label: 'Manage Library', isActive: false, onTap: () => Navigator.pushNamed(context, '/upload_books')),

          _SidebarItem(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin Information',
              isActive: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminInformationScreen()),
                );
              }
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF004D40), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  CircleAvatar(radius: 14, backgroundImage: profileVM.profileImageUrl != null ? NetworkImage(profileVM.profileImageUrl!) : null, child: profileVM.profileImageUrl == null ? const Icon(Icons.person, color: Colors.white, size: 14) : null),
                  const SizedBox(width: 10),
                  Expanded(child: Text(profileVM.adminName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _SidebarItem({required this.icon, required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(onTap: onTap, leading: Icon(icon, color: isActive ? const Color(0xFF004D40) : Colors.grey), title: Text(label, style: TextStyle(color: isActive ? const Color(0xFF004D40) : Colors.grey, fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)), dense: true);
  }
}

class _TopHeader extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool isMobile;

  const _TopHeader({required this.scaffoldKey, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final profileVM = Provider.of<ProfileViewModel>(context);
    return Container(
      height: 70,
      color: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => scaffoldKey.currentState?.openDrawer(),
            ),
          const Expanded(child: TextField(decoration: InputDecoration(hintText: 'Search modules...', prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none))),
          IconButton(icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 22), onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode)),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Row(
              children: [
                if (!isMobile) Text(profileVM.adminName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 12),
                CircleAvatar(radius: 16, backgroundColor: const Color(0xFF004D40), backgroundImage: profileVM.profileImageUrl != null ? NetworkImage(profileVM.profileImageUrl!) : null, child: profileVM.profileImageUrl == null ? const Icon(Icons.person, color: Colors.white, size: 18) : null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardModule {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String route;
  final double spacingAfter;

  const DashboardModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.route,
    this.spacingAfter = 12.0,
  });
}

final List<DashboardModule> dashboardModulesConfig = [
  const DashboardModule(
    title: 'Manage User',
    subtitle: 'System ke active users ko monitor aur manage krein.',
    icon: Icons.people_outline,
    iconColor: Color(0xFF004D40),
    backgroundColor: Color(0xFFE0F2F1),
    route: '/user_hub',
    spacingAfter: 8.0,
  ),
  const DashboardModule(
    title: 'Manage Scholar',
    subtitle: 'Scholars ki registration aur profiles check krein.',
    icon: Icons.school_outlined,
    iconColor: Color(0xFF00695C),
    backgroundColor: Color(0xFFE8F5E9),
    route: '/scholar_hub',
    spacingAfter: 8.0,
  ),
  const DashboardModule(
    title: 'Manage Sunnah and Deeds',
    subtitle: 'Daily Sunnah library aur activities update krein.',
    icon: Icons.auto_stories_outlined,
    iconColor: Color(0xFF00796B),
    backgroundColor: Color(0xFFFFF3E0),
    route: '/sunnah_deeds',
    spacingAfter: 8.0,
  ),
];