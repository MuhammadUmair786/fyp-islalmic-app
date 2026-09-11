import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/db_helper.dart';
import '../models/surah_model.dart';
import '../services/bookmark_service.dart';
import 'ayah_detail_screen.dart';
import '../theme/app_theme.dart';

class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _foundSurahs = [];
  bool _isLoading = true;
  
  int? _lastSurah;
  int? _lastAyah;
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  void initState() {
    super.initState();
    _fetchSurahs();
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSurah = prefs.getInt('last_surah');
      _lastAyah = prefs.getInt('last_ayah');
    });
  }

  void _fetchSurahs() async {
    try {
      final data = await DBHelper.getSurahList();
      if (mounted) {
        setState(() {
          _allSurahs = data;
          _foundSurahs = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Surah Fetch Error: $e");
      }
    }
  }

  void _runFilter(String enteredKeyword) {
    List<Map<String, dynamic>> results = [];
    if (enteredKeyword.isEmpty) {
      results = _allSurahs;
    } else {
      results = _allSurahs.where((surah) {
        int sNo = surah['surah_no'];
        String sName = Surah.surahNamesEn[sNo - 1].toLowerCase();
        return sName.contains(enteredKeyword.toLowerCase()) ||
            sNo.toString().contains(enteredKeyword);
      }).toList();
    }
    setState(() {
      _foundSurahs = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text("Al-Quran", 
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            indicatorColor: AppTheme.accentGreen,
            labelColor: AppTheme.accentGreen,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: "All Surahs"),
              Tab(text: "Favorites"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSurahList(context, _foundSurahs, isDark, true),
            _buildFavoritesTab(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahList(BuildContext context, List<Map<String, dynamic>> surahList, bool isDark, bool showSearch) {
    final size = MediaQuery.of(context).size;
    
    return Column(
      children: [
        if (showSearch) ...[
          if (_lastSurah != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FadeInDown(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AyahDetailScreen(
                          surahNo: _lastSurah!,
                          initialAyah: _lastAyah ?? 1,
                        ),
                      ),
                    ).then((_) => _loadLastRead());
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark ? [AppTheme.primaryLight, const Color(0xFF002921)] : [AppTheme.primaryLight, const Color(0xFF00695C)]
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppTheme.accentGreen.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, color: AppTheme.accentGreen, size: 30),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Resume Quran Reading", 
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("Surah ${Surah.surahNamesEn[_lastSurah! - 1]} • Ayah ${_lastAyah ?? 1}", 
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => _runFilter(value),
              style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search Surah Name or Number',
                hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey),
                prefixIcon: Icon(Icons.search, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
        ],

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
              : surahList.isEmpty 
                  ? Center(child: Text("No Surah found", style: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey)))
                  : StreamBuilder<DocumentSnapshot>(
                      stream: _bookmarkService.getBookmarksStream(),
                      builder: (context, snapshot) {
                        List favorites = [];
                        if (snapshot.hasData && snapshot.data!.exists) {
                          favorites = (snapshot.data!.data() as Map<String, dynamic>)['surah_favorites'] ?? [];
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: surahList.length,
                          itemBuilder: (context, index) {
                            int surahNo = surahList[index]['surah_no'];
                            Surah s = Surah.getSurahByNo(surahNo);
                            bool isFav = favorites.contains(surahNo);

                            return FadeInUp(
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : Colors.green.shade50,
                                  ),
                                  boxShadow: isDark ? [] : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4)
                                    )
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    height: 48, width: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.accentGreen.withValues(alpha: 0.3) : AppTheme.primaryLight.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(surahNo.toString(),
                                        style: GoogleFonts.poppins(
                                          color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, 
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16
                                        )),
                                  ),
                                  title: Text(s.nameEn,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold, 
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: size.width > 600 ? 18 : 16
                                      )),
                                  subtitle: Text("${s.type} • ${s.totalAyahs} Ayahs",
                                      style: GoogleFonts.poppins(
                                        color: isDark ? Colors.white60 : Colors.grey,
                                        fontSize: 12
                                      )),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(s.nameAr,
                                          style: GoogleFonts.amiri(
                                            fontSize: 20, 
                                            fontWeight: FontWeight.bold, 
                                            color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight
                                          )),
                                      const SizedBox(width: 10),
                                      IconButton(
                                        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, 
                                          color: isFav ? Colors.redAccent : (isDark ? Colors.white38 : Colors.grey)),
                                        onPressed: () => _bookmarkService.toggleSurahFavorite(surahNo),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AyahDetailScreen(surahNo: surahNo),
                                      ),
                                    ).then((_) => _loadLastRead());
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      }
                    ),
        ),
      ],
    );
  }

  Widget _buildFavoritesTab(BuildContext context, bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _bookmarkService.getBookmarksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
        }
        
        List favorites = [];
        if (snapshot.hasData && snapshot.data!.exists) {
          favorites = (snapshot.data!.data() as Map<String, dynamic>)['surah_favorites'] ?? [];
        }

        if (favorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 60, color: isDark ? Colors.white24 : Colors.grey.shade300),
                const SizedBox(height: 15),
                Text("No Favorite Surahs yet", 
                  style: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        List<Map<String, dynamic>> favSurahs = _allSurahs.where((s) => favorites.contains(s['surah_no'])).toList();
        return _buildSurahList(context, favSurahs, isDark, false);
      },
    );
  }
}
