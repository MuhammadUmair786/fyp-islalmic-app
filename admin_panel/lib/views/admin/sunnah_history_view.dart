import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SunnahDeedsView extends StatefulWidget {
  const SunnahDeedsView({super.key});

  @override
  State<SunnahDeedsView> createState() => _SunnahDeedsViewState();
}

class _SunnahDeedsViewState extends State<SunnahDeedsView> {
  final List<TextEditingController> _taskControllers = List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _pointsControllers = List.generate(3, (_) => TextEditingController(text: '10'));

  bool _isUploading = false;

  Future<void> _updateDailyTasks() async {
    bool hasEmpty = false;
    for (int i = 0; i < 3; i++) {
      if (_taskControllers[i].text.trim().isEmpty || _pointsControllers[i].text.trim().isEmpty) {
        hasEmpty = true;
        break;
      }
    }

    if (hasEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meharbani karke teeno deeds ke Titles aur Points lazmi likhein!')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      String todayDateStr = DateTime.now().toIso8601String().split('T')[0];

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      for (int i = 0; i < 3; i++) {
        DocumentReference docRef = firestore.collection('daily_deeds').doc();
        batch.set(docRef, {
          'title': _taskControllers[i].text.trim(),
          'points': int.tryParse(_pointsControllers[i].text.trim()) ?? 10,
          'createdAt': Timestamp.now(),
          'dateStr': todayDateStr,
          'deedIndex': i + 1,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('3 Daily Deeds Successfully Published! 🎉'), backgroundColor: Colors.green),
        );
      }

      for (int i = 0; i < 3; i++) {
        _taskControllers[i].clear();
        _pointsControllers[i].text = '10';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteDeed(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('daily_deeds').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deed Deleted Successfully! 🗑️'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    for (var c in _taskControllers) c.dispose();
    for (var c in _pointsControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String todayDateStr = DateTime.now().toIso8601String().split('T')[0];
    final screenWidth = MediaQuery.of(context).size.width;
    final double dynamicPadding = screenWidth > 800 ? 40.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Sunnah & Deeds Management'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Manage30DaysDeedsView()),
                );
              },
              icon: const Icon(Icons.calendar_month, size: 18),
              label: const Text('Manage 30-Day Program', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(dynamicPadding),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(dynamicPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Publish 3 Daily Sunnah/Deeds', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                        const SizedBox(height: 8),
                        const Text('Aap yahan aik sath 3 deeds aur unke points set kar ke publish kar sakte hain.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 24),
                        for (int i = 0; i < 3; i++) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _taskControllers[i],
                                  decoration: InputDecoration(
                                    labelText: 'Deed ${i + 1} Title',
                                    hintText: 'e.g., Smile, it\'s Sunnah.',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _pointsControllers[i],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Points',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (i < 2) const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 200,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: _isUploading ? null : _updateDailyTasks,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004D40),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                                  : const Text('Publish All 3 Deeds', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Divider(thickness: 1.5),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Today's History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SunnahHistoryView()));
                      },
                      icon: const Icon(Icons.history, size: 18, color: Color(0xFF004D40)),
                      label: const Text("View All History", style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('daily_deeds').where('dateStr', isEqualTo: todayDateStr).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xFF004D40))));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                        child: const Center(child: Text("No deeds active for today.", style: TextStyle(color: Colors.grey, fontSize: 15, fontStyle: FontStyle.italic))),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF004D40),
                              child: Text("+${data['points'] ?? 10}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: const Text("Active for today's users", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 26),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Sunnah/Deed?'),
                                    content: const Text('Kya aap waqai is task ko delete karna chahte hain?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteDeed(doc.id);
                                        },
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 📜 SUNNAH HISTORY VIEW
class SunnahHistoryView extends StatelessWidget {
  final String collectionName;
  final String appBarTitle;
  final String emptyMessage;

  const SunnahHistoryView({
    super.key,
    this.collectionName = 'daily_deeds',
    this.appBarTitle = 'All Published Deeds History',
    this.emptyMessage = 'History mein koi data nahi mila.',
  });

  String _parseFirebaseTimestamp(dynamic firestoreTimestamp) {
    if (firestoreTimestamp == null) return 'N/A';
    DateTime dateTime = (firestoreTimestamp as Timestamp).toDate();
    String year = dateTime.year.toString();
    String month = _getMonthName(dateTime.month);
    String day = dateTime.day.toString().padLeft(2, '0');
    int hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    if (hour == 0) hour = 12;
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return "$day $month $year, $hour:$minute $amPm";
  }

  String _getMonthName(int monthNum) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[monthNum - 1];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding = screenWidth > 800 ? 40.0 : 16.0;
    final double verticalPadding = screenWidth > 800 ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collectionName)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF004D40)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      emptyMessage,
                      style: const TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String formattedDateTime = _parseFirebaseTimestamp(data['createdAt']);
                    int points = data['points'] ?? 10;
                    String title = data['title'] ?? 'No Title';
                    int deedIndex = data['deedIndex'] ?? (index % 3) + 1;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF004D40),
                              radius: 18,
                              child: Text(
                                "$deedIndex",
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_filled, size: 13, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          "Published on: $formattedDateTime",
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2F1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Text(
                                "+$points pts",
                                style: const TextStyle(
                                  color: Color(0xFF004D40),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
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
        ),
      ),
    );
  }
}

// 📱 USER SIDE SCREEN TO VIEW TODAY'S 3 DEEDS
class UserDeedsView extends StatelessWidget {
  const UserDeedsView({super.key});

  @override
  Widget build(BuildContext context) {
    String todayDateStr = DateTime.now().toIso8601String().split('T')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Sunnah & Deeds'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('daily_deeds')
            .where('dateStr', isEqualTo: todayDateStr)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No deeds available for today yet.", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var deed = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF004D40),
                    child: Text(
                      "+${deed['points'] ?? 10}",
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    deed['title'] ?? 'Sunnah Deed',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text("Complete this deed to earn points!", style: TextStyle(color: Colors.grey, fontSize: 13)),
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

// 🗓️ 30 DAYS PROGRAM MANAGEMENT SCREEN (Updated with 3 Deeds per day & No Description)
class Manage30DaysDeedsView extends StatefulWidget {
  const Manage30DaysDeedsView({super.key});

  @override
  State<Manage30DaysDeedsView> createState() => _Manage30DaysDeedsViewState();
}

class _Manage30DaysDeedsViewState extends State<Manage30DaysDeedsView> {
  final List<List<TextEditingController>> _titleControllers = List.generate(
    30,
        (_) => List.generate(3, (_) => TextEditingController()),
  );

  final List<List<TextEditingController>> _pointsControllers = List.generate(
    30,
        (_) => List.generate(3, (_) => TextEditingController(text: '10')),
  );

  bool _isLoading = false;
  bool _isFetching = true;

  @override
  void initState() {
    super.initState();
    _fetchExisting30DaysData();
  }

  Future<void> _fetchExisting30DaysData() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('app_content').doc('ramadan_or_deeds_30_days').get();
      if (doc.exists && doc.data() != null) {
        List list = doc.data()!['deeds_list'] ?? [];
        for (int i = 0; i < list.length && i < 30; i++) {
          var dayData = list[i];
          if (dayData['deeds'] != null && dayData['deeds'] is List) {
            List dayDeeds = dayData['deeds'];
            for (int j = 0; j < dayDeeds.length && j < 3; j++) {
              _titleControllers[i][j].text = dayDeeds[j]['title'] ?? '';
              _pointsControllers[i][j].text = (dayDeeds[j]['points'] ?? 10).toString();
            }
          } else {
            // Fallback for old single data format if any exists in Firestore
            _titleControllers[i][0].text = dayData['title'] ?? '';
            _pointsControllers[i][0].text = (dayData['points'] ?? 10).toString();
          }
        }
      }
    } catch (e) {
      print("Error loading 30 days data: $e");
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _saveAll30Days() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> thirtyDaysList = [];

      for (int i = 0; i < 30; i++) {
        List<Map<String, dynamic>> dayDeedsList = [];
        for (int j = 0; j < 3; j++) {
          dayDeedsList.add({
            'deed_index': j + 1,
            'title': _titleControllers[i][j].text.trim(),
            'points': int.tryParse(_pointsControllers[i][j].text.trim()) ?? 10,
          });
        }

        thirtyDaysList.add({
          'day': i + 1,
          'deeds': dayDeedsList,
        });
      }

      await FirebaseFirestore.instance.collection('app_content').doc('ramadan_or_deeds_30_days').set({
        'total_days': 30,
        'deeds_list': thirtyDaysList,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('30 Days Program Successfully Saved! 🎉'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving data!'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (int i = 0; i < 30; i++) {
      for (int j = 0; j < 3; j++) {
        _titleControllers[i][j].dispose();
        _pointsControllers[i][j].dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Manage 30-Day Program (3 Deeds/Day)'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveAll30Days,
              icon: const Icon(Icons.save, size: 18),
              label: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save All 30 Days', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 30,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Day ${index + 1}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40)),
                  ),
                  const SizedBox(height: 12),
                  for (int j = 0; j < 3; j++) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _titleControllers[index][j],
                            decoration: InputDecoration(
                              labelText: 'Day ${index + 1} - Deed ${j + 1} Title',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _pointsControllers[index][j],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Points',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (j < 2) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}