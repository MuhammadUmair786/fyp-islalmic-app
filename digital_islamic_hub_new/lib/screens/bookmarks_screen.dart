import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BookmarkService _bookmarkService = BookmarkService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("My Bookmarks", 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentGreen,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          tabs: const [ Tab(text: "Hadiths"), Tab(text: "Ayahs") ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _bookmarkService.getBookmarksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("No bookmarks yet", style: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey)));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List hadiths = data['hadith_bookmarks_v2'] ?? [];
          List ayahs = data['ayah_bookmarks_v2'] ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookmarkList(hadiths, isDark, true),
              _buildBookmarkList(ayahs, isDark, false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookmarkList(List bookmarks, bool isDark, bool isHadith) {
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isHadith ? Icons.library_books_outlined : Icons.menu_book_outlined, size: 60, color: isDark ? Colors.white10 : Colors.grey.shade200),
            const SizedBox(height: 12),
            Text("No ${isHadith ? 'Hadith' : 'Ayah'} bookmarks", style: GoogleFonts.poppins(color: isDark ? Colors.white38 : Colors.grey)),
          ],
        ),
      );
    }

    // Sort by newest first
    bookmarks.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookmarks.length,
      itemBuilder: (context, i) {
        final b = bookmarks[i];
        String ref = isHadith 
          ? "${b['collection']} / Hadith ${b['hadithNo']}"
          : "Surah ${b['surahName']} / Ayah ${b['ayahNo']}";
        
        DateTime? dt = DateTime.tryParse(b['timestamp'] ?? '');
        String dateStr = dt != null ? DateFormat('dd MMM, hh:mm a').format(dt) : '';
        String lang = b['lang'] ?? 'en';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.green.shade50),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentGreen)),
                      Text(dateStr, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _bookmarkService.deleteBookmark(b['id'], isHadith),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(b['textAr'] ?? '', textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: GoogleFonts.scheherazadeNew(fontSize: 22, height: 1.6, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const Divider(height: 25, thickness: 0.5),
              Text(b['textTrans'] ?? '', 
                textAlign: lang == 'ur' ? TextAlign.right : TextAlign.left, 
                textDirection: lang == 'ur' ? TextDirection.rtl : TextDirection.ltr, 
                style: lang == 'ur' 
                  ? GoogleFonts.notoNastaliqUrdu(fontSize: 15, height: 2.2, color: isDark ? Colors.white70 : Colors.black87)
                  : GoogleFonts.poppins(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)
              ),
            ],
          ),
        );
      },
    );
  }
}
