import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import 'hadith_chapters_screen.dart';
import 'hadith_list_screen.dart';
import '../theme/app_theme.dart';

class HadithBooksScreen extends StatefulWidget {
  const HadithBooksScreen({super.key});

  @override
  State<HadithBooksScreen> createState() => _HadithBooksScreenState();
}

class _HadithBooksScreenState extends State<HadithBooksScreen> {
  String? _lastColl;
  String? _lastDisp;
  String? _lastChap;
  String? _lastTop;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastColl = prefs.getString('last_hadith_collection');
      _lastDisp = prefs.getString('last_hadith_display');
      _lastChap = prefs.getString('last_hadith_chapter');
      _lastTop = prefs.getString('last_hadith_topic');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Map<String, dynamic>> books = [
      {"collection": "bukhari", "name_en": "Sahih Bukhari", "name_ur": "صحیح بخاری"},
      {"collection": "muslim", "name_en": "Sahih Muslim", "name_ur": "صحیح مسلم"},
      {"collection": "abu-dawud", "name_en": "Sunan Abu Dawud", "name_ur": "سنن ابو داؤد"},
      {"collection": "tirmidhi", "name_en": "Jami at-Tirmidhi", "name_ur": "جامع الترمذی"}
    ];

    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, currentLocale, _) {
        final bool isUrdu = currentLocale.languageCode == 'ur';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              isUrdu ? "کتبِ احادیث" : "Hadith Collections",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
            ),
            backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: books.length + (_lastColl != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (_lastColl != null && index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: FadeInDown(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HadithListScreen(
                              collectionName: _lastColl!,
                              displayName: _lastDisp ?? "Hadith",
                              chapterName: _lastChap ?? "Chapter",
                              topicId: _lastTop,
                            ),
                          ),
                        ).then((_) => _loadProgress());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark ? [AppTheme.primaryLight, const Color(0xFF002921)] : [AppTheme.primaryLight, const Color(0xFF00695C)]
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_edu_rounded, color: AppTheme.accentGreen, size: 30),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isUrdu ? "مطالعہ دوبارہ شروع کریں" : "Resume Hadith Reading", 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text("${_lastDisp} • ${_lastChap}", 
                                    style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              final book = books[_lastColl != null ? index - 1 : index];
              final displayName = isUrdu ? book['name_ur']! : book['name_en']!;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.green.shade50),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: const Icon(Icons.menu_book, color: AppTheme.accentGreen),
                  title: Text(displayName, style: isUrdu ? GoogleFonts.notoNastaliqUrdu(fontWeight: FontWeight.bold, fontSize: 16) : GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(isUrdu ? "ابواب دیکھیں" : "Browse Chapters", style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => HadithChaptersScreen(collectionName: book['collection']!, displayName: displayName))).then((_) => _loadProgress());
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
