import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class DailyDeeds extends StatefulWidget {
  final String userId;
  const DailyDeeds({super.key, required this.userId});

  @override
  State<DailyDeeds> createState() => _DailyDeedsState();
}

class _DailyDeedsState extends State<DailyDeeds> {
  bool _isSubmitting = false;
  final Set<String> _localTicks = {};
  String _lastCheckedDate = "";

  @override
  void initState() {
    super.initState();
    _validateAndResetMissedStreakStrict();
    _lastCheckedDate = DateTime.now().toIso8601String().split('T')[0];
  }

  Future<void> _validateAndResetMissedStreakStrict() async {
    try {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      DocumentSnapshot snap = await userRef.get();

      if (snap.exists && snap.data() != null) {
        var data = snap.data() as Map<String, dynamic>;
        if (data['lastUpdate'] == null) return;

        Timestamp lastUpdateTimestamp = data['lastUpdate'] as Timestamp;
        DateTime lastUpdate = lastUpdateTimestamp.toDate();
        DateTime now = DateTime.now();

        DateTime todayMidnight = DateTime(now.year, now.month, now.day);
        DateTime lastUpdateMidnight = DateTime(lastUpdate.year, lastUpdate.month, lastUpdate.day);
        int differenceInDays = todayMidnight.difference(lastUpdateMidnight).inDays;

        if (differenceInDays > 1) {
          bool adminDeedsExistInGap = false;

          for (int i = 1; i < differenceInDays; i++) {
            DateTime missedDay = lastUpdateMidnight.add(Duration(days: i));
            String missedDayStr = missedDay.toIso8601String().split('T')[0];

            QuerySnapshot adminDeedsCheck = await FirebaseFirestore.instance
                .collection('daily_deeds')
                .where('dateStr', isEqualTo: missedDayStr)
                .get();

            if (adminDeedsCheck.docs.isNotEmpty) {
              adminDeedsExistInGap = true;
              break;
            }
          }

          if (adminDeedsExistInGap) {
            await userRef.update({
              'streak': 0,
              'completedTodayDate': "",
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error validating strict streak: $e");
    }
  }

  Future<void> _toggleDeed(String deedId, bool currentStatus, String todayStr) async {
    setState(() {
      if (currentStatus) {
        _localTicks.remove(deedId);
      } else {
        _localTicks.add(deedId);
      }
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('daily_progress')
          .doc(todayStr)
          .set({
        deedId: !currentStatus,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving deed status: $e");
    }
  }

  void _submitStreak(int pointsCalculated, String todayStr) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);

      DocumentSnapshot snap = await userRef.get();
      int currentStreak = 0;
      if (snap.exists) {
        currentStreak = (snap.data() as Map<String, dynamic>)['streak'] ?? 0;
      }

      await userRef.update({
        'totalPoints': FieldValue.increment(pointsCalculated),
        'streak': currentStreak + 1,
        'lastUpdate': Timestamp.now(),
        'completedTodayDate': todayStr,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("MashaAllah! Today's streak has been successfully updated!"), backgroundColor: AppTheme.primaryLight),
        );
      }
    } catch (e) {
      debugPrint("Firebase Write Error: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String todayStr = DateTime.now().toIso8601String().split('T')[0];

    if (_lastCheckedDate != todayStr) {
      _lastCheckedDate = todayStr;
      _localTicks.clear();
    }

    final double horizontalPadding = MediaQuery.of(context).size.width > 800 ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.primaryDark : const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text("Daily Sunnah & Deeds"),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, userSnap) {
          int displayStreak = 0;
          String lastDate = "";
          Timestamp? createdAt;

          if (userSnap.hasData && userSnap.data != null && userSnap.data!.exists) {
            final data = userSnap.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              displayStreak = data['streak'] ?? 0;
              lastDate = data['completedTodayDate'] ?? "";
              createdAt = data['createdAt'] as Timestamp?;
            }
          }

          bool alreadyDone = (lastDate == todayStr);

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('daily_progress')
                .doc(todayStr)
                .snapshots(),
            builder: (context, progressSnap) {
              Map<String, dynamic> savedProgress = {};
              if (progressSnap.hasData && progressSnap.data != null && progressSnap.data!.exists) {
                savedProgress = progressSnap.data!.data() as Map<String, dynamic>? ?? {};
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('app_content').doc('ramadan_or_deeds_30_days').snapshots(),
                builder: (context, thirtyDaysSnap) {
                  List<Map<String, dynamic>> todayDeedsList = [];

                  if (thirtyDaysSnap.hasData && thirtyDaysSnap.data != null && thirtyDaysSnap.data!.exists) {
                    var data = thirtyDaysSnap.data!.data() as Map<String, dynamic>?;
                    if (data != null && data['deeds_list'] != null) {
                      List list = data['deeds_list'];

                      int currentDayNumber = 1;
                      if (createdAt != null) {
                        DateTime startDate = createdAt.toDate();
                        DateTime now = DateTime.now();
                        int diffDays = DateTime(now.year, now.month, now.day).difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays;
                        currentDayNumber = (diffDays % 30) + 1;
                      }

                      for (var item in list) {
                        if (item['day'] == currentDayNumber) {
                          todayDeedsList.add({
                            'id': 'day_${currentDayNumber}_${item['title'].hashCode}',
                            'title': item['title'] ?? '',
                            'description': item['description'] ?? '',
                            'points': item['points'] ?? 5,
                          });
                        }
                      }
                    }
                  }

                  if (todayDeedsList.isEmpty) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('daily_deeds').where('dateStr', isEqualTo: todayStr).snapshots(),
                      builder: (context, fallbackSnap) {
                        if (fallbackSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
                        }
                        var deedsDocs = fallbackSnap.hasData ? fallbackSnap.data!.docs : [];

                        if (deedsDocs.isEmpty) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('daily_deeds').orderBy('dateStr', descending: true).limit(5).snapshots(),
                            builder: (context, lastDeedsSnap) {
                              if (lastDeedsSnap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
                              }
                              var lastDocs = lastDeedsSnap.hasData ? lastDeedsSnap.data!.docs : [];
                              if (lastDocs.isEmpty) {
                                return const Center(child: Text("No deeds available.", style: TextStyle(color: Colors.grey, fontSize: 16)));
                              }

                              List<Map<String, dynamic>> mappedDeeds = lastDocs.map((doc) {
                                var d = doc.data() as Map<String, dynamic>;
                                return {
                                  'id': doc.id,
                                  'title': d['title'] ?? '',
                                  'description': '',
                                  'points': d['points'] ?? 5,
                                };
                              }).toList();

                              return _buildDeedsContent(context, mappedDeeds, displayStreak, alreadyDone, savedProgress, todayStr, isDark, horizontalPadding);
                            },
                          );
                        }

                        List<Map<String, dynamic>> mappedDeeds = deedsDocs.map((doc) {
                          var d = doc.data() as Map<String, dynamic>;
                          return {
                            'id': doc.id,
                            'title': d['title'] ?? '',
                            'description': '',
                            'points': d['points'] ?? 5,
                          };
                        }).toList();

                        return _buildDeedsContent(context, mappedDeeds, displayStreak, alreadyDone, savedProgress, todayStr, isDark, horizontalPadding);
                      },
                    );
                  }

                  return _buildDeedsContent(context, todayDeedsList, displayStreak, alreadyDone, savedProgress, todayStr, isDark, horizontalPadding);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDeedsContent(BuildContext context, List<Map<String, dynamic>> deeds, int displayStreak, bool alreadyDone, Map<String, dynamic> savedProgress, String todayStr, bool isDark, double horizontalPadding) {
    int totalCalculatedPoints = 0;
    int checkedCount = 0;

    for (var deed in deeds) {
      String id = deed['id'];
      bool isChecked = alreadyDone || (savedProgress[id] == true) || _localTicks.contains(id);
      if (isChecked) {
        checkedCount++;
        totalCalculatedPoints += (deed['points'] as num).toInt();
      }
    }

    bool allDeedsCompleted = (deeds.isNotEmpty && checkedCount == deeds.length);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 1,
                color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 32),
                      const SizedBox(width: 10),
                      Text(
                        "$displayStreak Days Streak",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deeds.length,
                itemBuilder: (context, index) {
                  var deed = deeds[index];
                  String title = deed['title'];
                  String description = deed['description'];
                  String id = deed['id'];
                  int pts = deed['points'];

                  bool ticked = alreadyDone || (savedProgress[id] == true) || _localTicks.contains(id);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0.5,
                    color: isDark ? Colors.white.withAlpha(15) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accentGreen.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "+$pts",
                              style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: alreadyDone ? null : () {
                              bool currentStatus = (savedProgress[id] == true) || _localTicks.contains(id);
                              _toggleDeed(id, currentStatus, todayStr);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: ticked ? AppTheme.accentGreen : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(color: ticked ? AppTheme.accentGreen : Colors.grey, width: 2),
                              ),
                              child: ticked ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (alreadyDone || !allDeedsCompleted) ? Colors.grey : AppTheme.primaryLight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    elevation: 2,
                  ),
                  onPressed: (alreadyDone || !allDeedsCompleted || _isSubmitting)
                      ? null
                      : () => _submitStreak(totalCalculatedPoints, todayStr),
                  child: _isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                    alreadyDone
                        ? "Streak Updated ✔"
                        : (!allDeedsCompleted
                        ? "Complete all deeds ($checkedCount/${deeds.length})"
                        : "Update My Streak (Earn +$totalCalculatedPoints Pts)"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}