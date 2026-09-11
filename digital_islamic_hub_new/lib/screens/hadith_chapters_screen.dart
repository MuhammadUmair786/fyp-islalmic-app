import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart'; // localeNotifier ke liye
import '../core/database/db_helper.dart';
import 'hadith_list_screen.dart';
import '../theme/app_theme.dart';

class HadithChaptersScreen extends StatefulWidget {
  final String collectionName;
  final String displayName;

  const HadithChaptersScreen({
    super.key,
    required this.collectionName,
    required this.displayName,
  });

  @override
  State<HadithChaptersScreen> createState() => _HadithChaptersScreenState();
}

class _HadithChaptersScreenState extends State<HadithChaptersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allChapters = [];
  List<Map<String, dynamic>> _filteredChapters = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  void _loadChapters() async {
    final data = await DBHelper.getChaptersByBook(widget.collectionName);
    setState(() {
      _allChapters = data;
      _filteredChapters = data;
      _isLoading = false;
    });
  }

  void _filterChapters(String query, bool isUrdu) {
    setState(() {
      if (query.isEmpty) {
        _filteredChapters = _allChapters;
      } else {
        final cleanQuery = query.toLowerCase().trim();
        _filteredChapters = _allChapters.where((ch) {
          final nameUr = (ch['topic_name_ur'] ?? '').toString().toLowerCase();
          final nameEn = (ch['topic_name_en'] ?? '').toString().toLowerCase();
          final topicId = (ch['topic_id'] ?? '').toString();

          return nameUr.contains(cleanQuery) ||
              nameEn.contains(cleanQuery) ||
              topicId == cleanQuery;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 👈 Listens to global locale changes dynamically
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, currentLocale, _) {
        final bool isUrdu = currentLocale.languageCode == 'ur';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              widget.displayName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
            ),
            backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (q) => _filterChapters(q, isUrdu),
                  style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: isUrdu ? "باب کا نام یا نمبر تلاش کریں..." : "Search chapter by name or number...",
                    hintStyle: GoogleFonts.poppins(
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
                    : _filteredChapters.isEmpty
                    ? Center(
                  child: Text(
                    isUrdu ? "کوئی باب نہیں ملا" : "No Chapters Found",
                    style: GoogleFonts.poppins(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _filteredChapters.length,
                  itemBuilder: (context, index) {
                    final chapter = _filteredChapters[index];
                    int displayIndex = index + 1;

                    String chName = isUrdu
                        ? (chapter['topic_name_ur'] ?? "باب $displayIndex")
                        : (chapter['topic_name_en'] ?? "Chapter $displayIndex");

                    int startNo = chapter['start_no'] ?? 0;
                    int endNo = chapter['end_no'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.green.shade50),
                        boxShadow: isDark ? [] : [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        leading: Container(
                          height: 48, width: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            "$displayIndex",
                            style: GoogleFonts.poppins(
                              color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                            ),
                          ),
                        ),
                        title: Text(
                          chName,
                          style: isUrdu 
                            ? GoogleFonts.notoNastaliqUrdu(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              )
                            : GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            isUrdu ? "احادیث: $startNo تا $endNo" : "Hadiths: $startNo - $endNo",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HadithListScreen(
                                collectionName: widget.collectionName,
                                displayName: widget.displayName,
                                chapterName: chName,
                                topicId: chapter['topic_id'],
                              ),
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
        );
      },
    );
  }
}
