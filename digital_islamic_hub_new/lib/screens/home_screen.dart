import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:adhan/adhan.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../services/prayer_service.dart';
import '../services/notification_service.dart';
import '../services/safar_dua_service.dart';
import '../core/database/db_helper.dart';
import '../theme/app_theme.dart';
import '../models/mood_data.dart';
import '../widgets/app_logo.dart';
import 'masjid_map_screen.dart';
import 'masjid_silence_screen.dart';
import 'prayer_times_screen.dart';
import 'surah_list_screen.dart';
import 'ai_chat_screen.dart';
import 'tasbeeh_list_screen.dart';
import 'profile_screen.dart';
import 'safar_dua_screen.dart';
import 'hadith_books_screen.dart';
import 'bookmarks_screen.dart';
import 'user_book_list_view.dart';
import 'user_answer_screen.dart';
import 'user_notification_screen.dart';
import 'qibla_direction_finder.dart';
import '../services/qaza_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;

  // Mood Based State
  MoodCategory? _selectedMood;
  Map<String, dynamic>? _activeAyahData;
  bool _isMoodLoading = false;
  final GlobalKey _moodShareKey = GlobalKey();

  PrayerTimes? _cachedPrayerTimes;

  @override
  void initState() {
    super.initState();
    
    // Listen to prayer time updates to keep Home Screen in sync with other screens
    PrayerService.prayerTimesNotifier.addListener(_onPrayerTimesUpdated);
    
    // 🚀 Speed Optimization: Load quick cached times immediately
    _loadQuickPrayerTimes();
    
    Future.delayed(Duration.zero, () async {
      if (mounted) {
        _checkAndResetStreak();
        // 🔔 Consolidated permission request
        await NotificationService.requestPermissions();
        // 🔔 Ensure services are initialized (even if already done in main)
        await NotificationService.init(); 

        SafarDuaService.startIfEnabled();
        // Refresh with real location in background
        _refreshPrayerTimes();
      }
    });
  }

  void _onPrayerTimesUpdated() {
    if (mounted) {
      setState(() {
        _cachedPrayerTimes = PrayerService.prayerTimesNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    PrayerService.prayerTimesNotifier.removeListener(_onPrayerTimesUpdated);
    SafarDuaService.stop();
    super.dispose();
  }

  Future<void> _loadQuickPrayerTimes() async {
    final pt = await PrayerService.getQuickPrayerTimes();
    if (mounted) {
      setState(() {
        _cachedPrayerTimes = pt;
      });
      await QazaNotificationService.scheduleQazaChecks(pt);
    }
  }

  Future<void> _refreshPrayerTimes() async {
    final pt = await PrayerService.getPrayerTimes();
    if (mounted && pt != null) {
      setState(() {
        _cachedPrayerTimes = pt;
      });
      await QazaNotificationService.scheduleQazaChecks(pt);
    }
  }

  Future<void> _onMoodSelected(MoodCategory mood) async {
    setState(() {
      _selectedMood = mood;
      _isMoodLoading = true;
    });

    final ref = mood.refs[Random().nextInt(mood.refs.length)];
    final data = await DBHelper.getAyahByReference(ref.surah, ref.ayah);

    if (mounted) {
      setState(() {
        _activeAyahData = data;
        _isMoodLoading = false;
      });
    }
  }

  Future<void> _shareMoodAyah(String text) async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      final RenderRepaintBoundary? boundary = _moodShareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      var pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/mood_ayah_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await imagePath.writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(imagePath.path)], text: text);
    } catch (e) {
      debugPrint("Share Error: $e");
    }
  }

  Future<void> _checkAndResetStreak() async {
    if (user == null) return;
    try {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      var snapshot = await userRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data['lastUpdate'] != null) {
          DateTime lastUpdate = (data['lastUpdate'] as Timestamp).toDate();
          DateTime now = DateTime.now();
          bool isNewDay = now.year != lastUpdate.year || now.month != lastUpdate.month || now.day != lastUpdate.day;
          if (isNewDay) {
            await userRef.update({'completedToday': [], 'isDaySubmitted': false});
          }
        }
      }
    } catch (e) { debugPrint("Streak Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> tabs = [ _buildHomeDashboardView(), const SurahListScreen(), const HadithBooksScreen(), const BookmarksScreen(), const UserBookListView() ];
    return Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor, body: IndexedStack(index: _selectedIndex, children: tabs), bottomNavigationBar: _buildBottomNav(isDark));
  }

  Widget _buildHomeDashboardView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isDark ? [AppTheme.primaryLight, AppTheme.primaryDark] : [const Color(0xFFE8F5E9), Colors.white])),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [ 
            _buildHeader(isDark), 
            SliverToBoxAdapter(
              child: Column(
                children: [ 
                  GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrayerTimesScreen())), child: _buildPrayerCard(isDark)), 
                  const SizedBox(height: 5),
                  _buildMoodModule(isDark),
                  const SizedBox(height: 10),
                  _buildGridMenu(isDark), 
                  const SizedBox(height: 15),
                  _buildDeedsModule(isDark), 
                  const SizedBox(height: 30) 
                ]
              )
            ) 
          ]
        )
      )
    );
  }

  Widget _buildMoodModule(bool isDark) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isUrdu = locale.languageCode == 'ur';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(isUrdu ? "آپ کیسا محسوس کر رہے ہیں؟" : "How are you feeling?", 
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: moodDataset.length,
                itemBuilder: (context, index) {
                  final mood = moodDataset[index];
                  bool isSelected = _selectedMood == mood;
                  return GestureDetector(
                    onTap: () => _onMoodSelected(mood),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accentGreen : (isDark ? Colors.white10 : Colors.white),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          Text(mood.icon, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(mood.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.black87 : (isDark ? Colors.white70 : Colors.black54))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isMoodLoading)
              const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator(color: AppTheme.accentGreen, strokeWidth: 2)))
            else if (_activeAyahData != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _moodShareKey,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark 
                                ? [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]
                                : [Colors.white, const Color(0xFFF1F8E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: isDark ? Colors.white12 : AppTheme.accentGreen.withValues(alpha: 0.3), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "Surah ${_activeAyahData!['surah_no']}:${_activeAyahData!['ayah_no']}",
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: isDark ? [Colors.white, Colors.white70] : [AppTheme.primaryLight, const Color(0xFF004D40)],
                              ).createShader(bounds),
                              child: Text(
                                _activeAyahData!['arabic_text'] ?? "",
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                                style: GoogleFonts.amiri(
                                  fontSize: 24,
                                  color: Colors.white,
                                  height: 1.6,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                isUrdu ? (_activeAyahData!['urdu_trans'] ?? "") : (_activeAyahData!['eng_trans'] ?? ""),
                                textAlign: TextAlign.center,
                                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                                style: isUrdu 
                                  ? GoogleFonts.notoNastaliqUrdu(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, height: 2.3)
                                  : GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54, fontStyle: FontStyle.italic, height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 25),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const AppLogo(radius: 10),
                                const SizedBox(width: 8),
                                Text(
                                  "Digital Islamic Hub",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white30 : Colors.grey.shade400,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 15,
                      right: 15,
                      child: Row(
                        children: [
                          _circleIconButton(
                            icon: Icons.share_rounded,
                            color: Colors.blue.withValues(alpha: 0.1),
                            iconColor: Colors.blueAccent,
                            onTap: () => _shareMoodAyah("Surah ${_activeAyahData!['surah_no']}:${_activeAyahData!['ayah_no']}\nShared via Digital Islamic Hub"),
                          ),
                          const SizedBox(width: 8),
                          _circleIconButton(
                            icon: Icons.close_rounded,
                            color: Colors.red.withValues(alpha: 0.1),
                            iconColor: Colors.redAccent,
                            onTap: () => setState(() { _activeAyahData = null; _selectedMood = null; }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }
    );
  }

  Widget _buildHeader(bool isDark) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            String name = user?.displayName ?? "User";
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data != null) name = data['name'] ?? data['displayName'] ?? "User";
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                        const AppLogo(radius: 25),
                        const SizedBox(width: 12),
                        Text("Digital Islamic Hub", style: GoogleFonts.poppins(color: isDark ? Colors.white : AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 18)),
                    ]),
                    Row(children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: currentUserId).where('isRead', isEqualTo: false).snapshots(),
                          builder: (context, snapshot) {
                            int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return Stack(alignment: Alignment.center, children: [
                                IconButton(icon: Icon(Icons.notifications_active_outlined, size: 26, color: unreadCount > 0 ? Colors.red : (isDark ? Colors.white : AppTheme.primaryLight)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserNotificationScreen()))),
                                if (unreadCount > 0) Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
                            ]);
                          },
                        ),
                        _buildAvatar(isDark),
                    ]),
                ]),
                const SizedBox(height: 15),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("Assalamu Alaikum, ", style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(name, style: GoogleFonts.poppins(color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 20, height: 1.1)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        String? img;
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          img = data?['profileImage'];
        }
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
          child: CircleAvatar(radius: 22, backgroundColor: isDark ? Colors.white10 : AppTheme.primaryLight.withValues(alpha: 0.12), backgroundImage: (img != null && img.isNotEmpty) ? NetworkImage(img) : null, child: (img == null || img.isEmpty) ? Icon(Icons.person, color: isDark ? Colors.white : AppTheme.primaryLight) : null),
        );
      },
    );
  }

  Widget _buildPrayerCard(bool isDark) {
    var hijri = HijriCalendar.now();
    if (_cachedPrayerTimes == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        height: 120,
        decoration: BoxDecoration(color: isDark ? AppTheme.primaryLight.withValues(alpha: 0.2) : Colors.green.shade50, borderRadius: BorderRadius.circular(24)),
        child: const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen)),
      );
    }

    final pt = _cachedPrayerTimes!;
    Prayer current = pt.currentPrayer();
    Prayer next = pt.nextPrayer();
    
    DateTime? currentTime = pt.timeForPrayer(current);
    DateTime? nextTime = pt.timeForPrayer(next);
    
    String currentName = current == Prayer.none ? "---" : current.name.toUpperCase();
    String nextName = next.name.toUpperCase();

    // Handle case where next prayer is tomorrow (e.g. after Isha)
    if (next == Prayer.none) {
      nextName = "FAJR";
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowPt = PrayerTimes(
        pt.coordinates,
        DateComponents.from(tomorrow),
        pt.calculationParameters,
      );
      nextTime = tomorrowPt.fajr;
    }

    // Handle case before Fajr (Current is none, Next is Fajr)
    if (current == Prayer.none && next == Prayer.fajr) {
       currentName = "ISHA";
       final yesterday = DateTime.now().subtract(const Duration(days: 1));
       final yesterdayPt = PrayerTimes(
         pt.coordinates,
         DateComponents.from(yesterday),
         pt.calculationParameters,
       );
       currentTime = yesterdayPt.isha;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), 
      padding: const EdgeInsets.symmetric(vertical: 18), 
      decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [AppTheme.primaryLight, const Color(0xFF002921)] : [AppTheme.primaryLight, const Color(0xFF00695C)]), borderRadius: BorderRadius.circular(24)), 
      child: Column(
        children: [ 
          FittedBox(child: Text("${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))), 
          const SizedBox(height: 12), 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, 
            children: [ 
              _prayerCol("CURRENT", currentName, currentTime), 
              _prayerCol("NEXT", nextName, nextTime) 
            ]
          ) 
        ]
      )
    );
  }

  Widget _prayerCol(String label, String name, DateTime? time) {
    String formattedTime = time != null ? DateFormat.jm().format(time) : "--:--";
    return Column(children: [ 
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)), 
      FittedBox(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))), 
      Text(formattedTime, style: const TextStyle(color: AppTheme.accentGreen, fontSize: 12)) 
    ]);
  }

  Widget _buildGridMenu(bool isDark) {
    Color bg = isDark ? Colors.white.withValues(alpha: 0.13) : Colors.white;
    Color border = isDark ? Colors.white10 : Colors.green.shade50;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double aspectRatio = (width / 3) / 95; 
          return GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, 
            childAspectRatio: aspectRatio, 
            children: [
              _actionBtn("Islamic AI", Icons.smart_toy_rounded, Colors.cyan, isDark, bg, border, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AIChatScreen()))),
              _actionBtn("Tasbeeh", Icons.track_changes, Colors.blueAccent, isDark, bg, border, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TasbeehListScreen()))),
              _actionBtn("Safar Dua", Icons.travel_explore_rounded, Colors.teal, isDark, bg, border, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SafarDuaScreen()))),
              _actionBtn("User Answers", Icons.question_answer_rounded, Colors.orange, isDark, bg, border, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserAnswerScreen()))),
              _actionBtn("Qibla Finder", Icons.mosque, Colors.orange, isDark, bg, border, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QiblaFinderScreen()))),
              _actionBtn("Masjid Silence", Icons.mosque, Colors.orange, isDark, bg, border, onTap: () async {
                  final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'user_masjid_config';
                  final doc = await FirebaseFirestore.instance.collection('masjid_settings').doc(uid).get();
                  if (mounted) {
                    bool hasSaved = false;
                    if (doc.exists && doc.data() != null) {
                      List saved = (doc.data() as Map<String, dynamic>)['saved_mosques'] ?? [];
                      if (saved.isNotEmpty) hasSaved = true;
                    }
                    Navigator.push(context, MaterialPageRoute(builder: (context) => hasSaved ? const MasjidSettingsScreen() : const MasjidMapScreen()));
                  }
                }),
            ]
          );
        },
      ),
    );
  }

  Widget _actionBtn(String t, IconData i, Color c, bool isDark, Color bg, Color b, {VoidCallback? onTap}) {
    return GestureDetector(onTap: onTap, child: Container(decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: b)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(i, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, size: 24), const SizedBox(height: 4), Flexible(child: FittedBox(child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)))) ])));
  }

  Widget _circleIconButton({required IconData icon, required Color color, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  Widget _buildDeedsModule(bool isDark) {
    if (user == null) return const SizedBox();
    int currentDay = ((DateTime.now().day - 1) % 30) + 1;
    String documentId = "day_$currentDay";
    final screenWidth = MediaQuery.of(context).size.width;
    final double horizontalMargin = screenWidth > 800 ? 32.0 : 15.0;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, userSnap) {
        var userData = (userSnap.hasData && userSnap.data!.exists) ? userSnap.data!.data() as Map<String, dynamic> : {};
        int currentStreak = userData['streak'] ?? 0;
        List completedToday = userData['completedToday'] ?? [];
        bool isAlreadySubmitted = userData['isDaySubmitted'] ?? false;
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('daily_deeds').doc(documentId).snapshots(),
          builder: (context, snapshot) {
            List tasks = [];
            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              var rawDeeds = data['deeds'] ?? data['tasks'] ?? data['items'] ?? [];
              if (rawDeeds is List) {
                tasks = rawDeeds.map((item) {
                  if (item is Map) {
                    String title = (item['title'] ?? item['name'] ?? '').toString();
                    if (title.trim().isEmpty) title = 'Deed';
                    return {'title': title, 'points': (item['points'] ?? 2)};
                  }
                  return {'title': 'Deed', 'points': 2};
                }).toList();
              }
            }
            
            final List defaultDeeds = [
              {'title': 'Recite Surah Al-Mulk', 'points': 3},
              {'title': 'Give a small Sadaqah', 'points': 2},
              {'title': 'Read one page of Quran', 'points': 3}
            ];
            
            // Filter out invalid/empty tasks first
            tasks.removeWhere((t) => (t['title'] as String).trim() == 'Deed' || (t['title'] as String).isEmpty);

            if (tasks.length < 3) {
              for (var d in defaultDeeds) {
                if (tasks.length >= 3) break;
                if (!tasks.any((t) => t['title'] == d['title'])) {
                  tasks.add(d);
                }
              }
            }
            return Center(child: Container(constraints: const BoxConstraints(maxWidth: 800), margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Row(children: [ const Icon(Icons.auto_awesome, color: Colors.orange, size: 20), const SizedBox(width: 8), Text("Daily Sunnah & Deeds", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)) ]), Text("🔥 Streak: $currentStreak", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)) ])),
                ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: tasks.length, itemBuilder: (context, index) {
                    var task = tasks[index]; String deedKey = "task_$index"; bool isCompleted = completedToday.contains(deedKey);
                    return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(13) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isCompleted ? AppTheme.accentGreen.withAlpha(150) : (isDark ? Colors.white10 : Colors.green.shade50))), child: CheckboxListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: Text(task['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)), secondary: CircleAvatar(backgroundColor: Colors.orange.withAlpha(30), radius: 15, child: Text("+${task['points']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange))), value: isCompleted, activeColor: AppTheme.accentGreen, onChanged: (bool? value) async { List compToday = List.from(completedToday); if (value == true) { if (!compToday.contains(deedKey)) compToday.add(deedKey); } else { compToday.remove(deedKey); } await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({'completedToday': compToday}, SetOptions(merge: true)); }));
                }),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () async {
                    if (isAlreadySubmitted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deeds already completed!"), backgroundColor: Colors.orange)); return; }
                    bool allTasksCompleted = tasks.asMap().entries.every((entry) => completedToday.contains("task_${entry.key}"));
                    if (!allTasksCompleted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complete all tasks first! ❌"), backgroundColor: Colors.red)); return; }
                    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
                    var uSnap = await userRef.get(); var uData = uSnap.exists ? uSnap.data() as Map<String, dynamic> : {};
                    int streak = uData['streak'] ?? 0; int earnedPoints = 0; for (var t in tasks) earnedPoints += (t['points'] as num).toInt();
                    int newStreak = streak + 1; await userRef.set({'totalPoints': (uData['totalPoints'] ?? 0) + earnedPoints, 'streak': newStreak, 'isDaySubmitted': true, 'lastUpdate': Timestamp.now()}, SetOptions(merge: true));
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Congratulations! Streak: $newStreak 🎉"), backgroundColor: Colors.green));
                }, child: Text(isAlreadySubmitted ? "Completed ✅" : "Complete & Submit Streak 🎉", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))))
            ])));
          },
        );
      },
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return BottomNavigationBar(currentIndex: _selectedIndex, onTap: (i) => setState(() => _selectedIndex = i), type: BottomNavigationBarType.fixed, backgroundColor: isDark ? const Color(0xFF001A12) : Colors.white, selectedItemColor: AppTheme.accentGreen, unselectedItemColor: isDark ? Colors.white38 : Colors.grey.shade400, items: const [ BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"), BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: "Quran"), BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: "Hadith"), BottomNavigationBarItem(icon: Icon(Icons.bookmark_rounded), label: "Bookmarks"), BottomNavigationBarItem(icon: Icon(Icons.collections_bookmark_rounded), label: "Books") ]);
  }
}
