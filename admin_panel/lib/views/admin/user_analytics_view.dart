import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class UserAnalyticsView extends StatelessWidget {
  const UserAnalyticsView({super.key});

  Stream<Map<String, int>> getAnalyticsData() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'User')
        .snapshots()
        .map((snapshot) {
      int active = 0;
      int blocked = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data['status'] == 'active') active++;
        if (data['status'] == 'blocked') blocked++;
      }

      return {'total': snapshot.docs.length, 'active': active, 'blocked': blocked};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("User Analytics & Charts"),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Map<String, int>>(
        stream: getAnalyticsData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          var data = snapshot.data ?? {'total': 0, 'active': 0, 'blocked': 0};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("User Analytics Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // 1. COUNTERS SECTION
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

                // 2. CHART SECTION
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
                      maxY: (data['total']! + 5).toDouble(),
                      barGroups: [
                        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: data['total']!.toDouble(), color: Colors.blue, width: 30, borderRadius: BorderRadius.circular(6))]),
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: data['active']!.toDouble(), color: Colors.green, width: 30, borderRadius: BorderRadius.circular(6))]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: data['blocked']!.toDouble(), color: Colors.red, width: 30, borderRadius: BorderRadius.circular(6))]),
                      ],
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0: return const Text('Total', style: TextStyle(fontSize: 12));
                                case 1: return const Text('Active', style: TextStyle(fontSize: 12));
                                case 2: return const Text('Blocked', style: TextStyle(fontSize: 12));
                                default: return const Text('');
                              }
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
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
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
