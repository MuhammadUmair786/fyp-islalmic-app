import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class UserManagementHubView extends StatelessWidget {
  const UserManagementHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D40),
      appBar: AppBar(
        title: const Text('User & Analytics Hub'),
        backgroundColor: const Color(0xFF002921),
        foregroundColor: Colors.yellow,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(100),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HubCard(
                title: 'Manage Users',
                subtitle: 'Control user access, block or unblock accounts.',
                icon: Icons.manage_accounts_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageUsersListScreen()),
                  );
                },
              ),
              const SizedBox(width: 32),
              _HubCard(
                title: 'User Analytics',
                subtitle: 'View detailed charts and registration statistics.',
                icon: Icons.analytics_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserAnalyticsDetailScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 260,
      child: Card(
        elevation: 2,
        color: const Color(0xFFF1F5F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 50, color: const Color(0xFF004D40)),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 📋 2. MANAGE USERS LIST SCREEN (Firebase Connection for Block/Unblock)
// =========================================================================
class ManageUsersListScreen extends StatefulWidget {
  const ManageUsersListScreen({super.key});

  @override
  State<ManageUsersListScreen> createState() => _ManageUsersListScreenState();
}

class _ManageUsersListScreenState extends State<ManageUsersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  void _toggleUserStatus(String docId, String currentStatus) async {
    String newStatus = currentStatus == 'blocked' ? 'active' : 'blocked';
    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).update({
        'status': newStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("User account is now $newStatus! 🔐"),
            backgroundColor: newStatus == 'active' ? Colors.green : Colors.red,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("Manage Users Account Control"),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Registered Users List", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(
                  width: 300,
                  height: 45,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Search user by email...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Database mein koi user nahi mila."));
                  }

                  var docs = snapshot.data!.docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String email = (data['email'] ?? '').toString().toLowerCase();
                    return email.contains(_searchQuery);
                  }).toList();

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        String email = data['email'] ?? 'No Email';
                        String status = data['status'] ?? 'active';

                        bool isBlocked = (status == 'blocked');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isBlocked ? Colors.red.shade100 : const Color(0xFFE0F2F1),
                            child: Icon(
                              isBlocked ? Icons.block : Icons.person_outline,
                              color: isBlocked ? Colors.red : const Color(0xFF004D40),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                email,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isBlocked ? Colors.grey : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isBlocked ? Colors.red.shade100 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isBlocked ? "Blocked" : "Active",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isBlocked ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                ),
                              )
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isBlocked ? Colors.green : Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                            label: Text(isBlocked ? "Unblock Account" : "Block Account"),
                            onPressed: () => _toggleUserStatus(doc.id, status),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 📊 3. USER ANALYTICS SCREEN WITH LIVE BAR CHART
// =========================================================================
class UserAnalyticsDetailScreen extends StatelessWidget {
  const UserAnalyticsDetailScreen({super.key});

  Stream<Map<String, int>> getAnalyticsData() {
    return FirebaseFirestore.instance.collection('users').snapshots().map((snapshot) {
      int active = 0;
      int blocked = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'blocked') {
          blocked++;
        } else {
          active++;
        }
      }

      return {'total': snapshot.docs.length, 'active': active, 'blocked': blocked};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("User Analytics & Statistics Charts"),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Map<String, int>>(
        stream: getAnalyticsData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }

          var data = snapshot.data ?? {'total': 0, 'active': 0, 'blocked': 0};

          double calculatedMaxY = (data['total'] ?? 0).toDouble() + 3.0;
          if (calculatedMaxY < 10) calculatedMaxY = 10;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("User Analytics Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                Row(
                  children: [
                    _buildStaticCard("Total Users", data['total'].toString(), Colors.blue, Icons.people_outline),
                    const SizedBox(width: 16),
                    _buildStaticCard("Active Users", data['active'].toString(), Colors.green, Icons.check_circle_outline),
                    const SizedBox(width: 16),
                    _buildStaticCard("Blocked Users", data['blocked'].toString(), Colors.red, Icons.block_outlined),
                  ],
                ),

                const SizedBox(height: 40),
                const Text("Visual Statistics (Bar Chart)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                Container(
                  height: 350,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: calculatedMaxY,
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: data['total']!.toDouble(), color: Colors.blue, width: 35, borderRadius: BorderRadius.circular(6))]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: data['active']!.toDouble(), color: Colors.green, width: 35, borderRadius: BorderRadius.circular(6))]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: data['blocked']!.toDouble(), color: Colors.red, width: 35, borderRadius: BorderRadius.circular(6))]),
                      ],
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0: return const Padding(padding: EdgeInsets.only(top: 6.0), child: Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                                case 1: return const Padding(padding: EdgeInsets.only(top: 6.0), child: Text('Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                                case 2: return const Padding(padding: EdgeInsets.only(top: 6.0), child: Text('Blocked', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                                default: return const Text('');
                              }
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaticCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border(left: BorderSide(color: color, width: 5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}