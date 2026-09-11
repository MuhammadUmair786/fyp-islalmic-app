import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sunnah_history_view.dart';

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

class UserDeedsView extends StatelessWidget {
  const UserDeedsView({super.key});

  // 🔄 Automatic 30-Day Loop Calculation Logic for Users
  int _calculateCurrentActiveDay(Timestamp? startDateTimestamp) {
    if (startDateTimestamp == null) return 1;
    DateTime startDate = startDateTimestamp.toDate();
    DateTime now = DateTime.now();

    // Difference in days (har 24 hours ke baad +1 day barh jayega)
    int differenceInDays = now.difference(startDate).inDays;

    // Modulo 30 lagane se jese hi 30 din khatam honge, yeh automatically wapas 0 ho kar +1 yaani Day 1 se shuru ho jayega (Infinite Loop)
    return (differenceInDays % 30) + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('30-Day Sunnah Program'),
        backgroundColor: const Color(0xFF004D40),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('app_content').doc('ramadan_or_deeds_30_days').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No 30-day program available yet.", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          Timestamp? startDate = data['program_start_date'];
          List deedsList = data['deeds_list'] ?? [];

          if (deedsList.isEmpty) {
            return const Center(child: Text("Program list is empty.", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          // 🚀 Calculate current day index based on 24-hour / day-by-day loop rotation (1 to 30)
          int activeDayNumber = _calculateCurrentActiveDay(startDate);

          // Find the deed corresponding to the active day (Day index is 1-based, list is 0-based index)
          var currentDayDeed = deedsList.firstWhere(
                (element) => element['day'] == activeDayNumber,
            orElse: () => deedsList[0],
          );

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004D40),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Streak / Program: Day $activeDayNumber of 30",
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentDayDeed['title'] ?? 'Sunnah Task',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Today's Details & Description:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        currentDayDeed['description'] ?? 'No description provided for today.',
                        style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                      ),
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
}

class Manage30DaysDeedsView extends StatefulWidget {
  const Manage30DaysDeedsView({super.key});

  @override
  State<Manage30DaysDeedsView> createState() => _Manage30DaysDeedsViewState();
}

class _Manage30DaysDeedsViewState extends State<Manage30DaysDeedsView> {
  final List<TextEditingController> _titleControllers = List.generate(30, (_) => TextEditingController());
  final List<TextEditingController> _descControllers = List.generate(30, (_) => TextEditingController());
  final List<TextEditingController> _pointsControllers = List.generate(30, (_) => TextEditingController(text: '10'));

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
          _titleControllers[i].text = list[i]['title'] ?? '';
          _descControllers[i].text = list[i]['description'] ?? '';
          _pointsControllers[i].text = (list[i]['points'] ?? 10).toString();
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
        thirtyDaysList.add({
          'day': i + 1,
          'title': _titleControllers[i].text.trim(),
          'description': _descControllers[i].text.trim(),
          'points': int.tryParse(_pointsControllers[i].text.trim()) ?? 10,
        });
      }

      // 🚀 Save with program start date so the 24-hour cycle loop starts fresh from today
      await FirebaseFirestore.instance.collection('app_content').doc('ramadan_or_deeds_30_days').set({
        'total_days': 30,
        'deeds_list': thirtyDaysList,
        'program_start_date': FieldValue.serverTimestamp(), // 👈 Yeh track karega ke 24 hours kab se shuru huwe hain
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('30 Days Program & Loop Saved Successfully! 🎉'), backgroundColor: Colors.green),
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
    for (var c in _titleControllers) c.dispose();
    for (var c in _descControllers) c.dispose();
    for (var c in _pointsControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Manage 30-Day Program'),
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
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _titleControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Day ${index + 1} Title',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _pointsControllers[index],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Points',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descControllers[index],
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description / Details for Day ${index + 1}',
                      border: const OutlineInputBorder(),
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