import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../core/database/db_helper.dart';
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';

class HadithListScreen extends StatefulWidget {
  final String collectionName;
  final String displayName;
  final String chapterName;
  final dynamic topicId;

  const HadithListScreen({
    super.key,
    required this.collectionName,
    required this.displayName,
    required this.chapterName,
    required this.topicId,
  });

  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  List<Map<String, dynamic>> _allHadiths = [];
  bool _isLoading = true;
  final BookmarkService _bookmarkService = BookmarkService();
  final Map<int, GlobalKey> _shareKeys = {};

  @override
  void initState() {
    super.initState();
    _loadChapterHadiths();
    _saveProgress(); 
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_hadith_collection', widget.collectionName);
    await prefs.setString('last_hadith_display', widget.displayName);
    await prefs.setString('last_hadith_chapter', widget.chapterName);
    await prefs.setString('last_hadith_topic', widget.topicId.toString());
  }

  void _loadChapterHadiths() async {
    try {
      final List<Map<String, dynamic>> data = await DBHelper.getHadithsByTopic(
        collectionName: widget.collectionName,
        topicId: widget.topicId,
      );

      if (mounted) {
        setState(() {
          _allHadiths = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Error fetching hadiths: $e");
      }
    }
  }

  Future<void> _shareHadith(GlobalKey key, String text) async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      final RenderRepaintBoundary? boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return;
      var pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final String fileName = 'hadith_${DateTime.now().millisecondsSinceEpoch}.png';
      final imagePath = await File('${directory.path}/$fileName').create();
      await imagePath.writeAsBytes(pngBytes);

      await Share.shareXFiles([XFile(imagePath.path)], text: text);
    } catch (e) {
      debugPrint("Share Error: $e");
    }
  }

  bool _isValidText(dynamic text) {
    if (text == null) return false;
    String str = text.toString().trim();
    return str.isNotEmpty && !str.contains("not available");
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isUrdu = locale.languageCode == 'ur';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.displayName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 2),
                Text(widget.chapterName, style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis),
              ],
            ),
            backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen))
              : _allHadiths.isEmpty
              ? Center(child: Text(isUrdu ? "کوئی حدیث نہیں ملی" : "No Hadith Found", style: GoogleFonts.poppins(color: isDark ? Colors.white60 : Colors.black54)))
              : StreamBuilder<DocumentSnapshot>(
            stream: _bookmarkService.getBookmarksStream(),
            builder: (context, animSnapshot) {
              List bookmarkedHadithIds = [];
              if (animSnapshot.hasData && animSnapshot.data!.exists) {
                var data = animSnapshot.data!.data() as Map<String, dynamic>;
                List bookmarks = data['hadith_bookmarks_v2'] ?? [];
                bookmarkedHadithIds = bookmarks.map((e) => e['id']).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _allHadiths.length,
                itemBuilder: (context, i) {
                  var h = _allHadiths[i];
                  String hNo = h['hadith_no'].toString();
                  String currentId = "${widget.collectionName.toLowerCase()}_$hNo";
                  bool isBookmarked = bookmarkedHadithIds.contains(currentId);
                  
                  int keyIndex = int.tryParse(hNo) ?? i;
                  _shareKeys[keyIndex] = _shareKeys[keyIndex] ?? GlobalKey();

                  String status = isUrdu ? (h['status_ur'] ?? 'صحیح') : (h['status_en'] ?? 'Sahih');
                  bool hasArText = _isValidText(h['text_ar']);
                  bool hasTransText = isUrdu ? _isValidText(h['text_ur']) : _isValidText(h['text_en']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Stack(
                      children: [
                        // 🖼️ SHAREABLE CARD CONTENT
                        RepaintBoundary(
                          key: _shareKeys[keyIndex],
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.green.shade50),
                              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.accentGreen.withValues(alpha: 0.4) : AppTheme.primaryLight.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(isUrdu ? "حدیث نمبر $hNo" : "Hadith $hNo", style: GoogleFonts.poppins(color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                if (hasArText)
                                  Text(h['text_ar'].toString(), textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: GoogleFonts.scheherazadeNew(fontSize: size.width > 600 ? 30 : 26, height: 1.6, color: isDark ? Colors.white : AppTheme.primaryLight, fontWeight: FontWeight.bold, shadows: isDark ? [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(1, 1))] : []))
                                else
                                  _fallbackBadge("المتن العربي غير متوفر حالياً", isDark),

                                Padding(padding: const EdgeInsets.symmetric(vertical: 18.0), child: Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, thickness: 0.8)),

                                if (hasTransText)
                                  Text(isUrdu ? h['text_ur'].toString() : h['text_en'].toString(), textAlign: isUrdu ? TextAlign.right : TextAlign.left, textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr, style: isUrdu ? GoogleFonts.notoNastaliqUrdu(fontSize: 15, height: 2.2, color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87) : GoogleFonts.poppins(fontSize: 14, height: 1.6, color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87))
                                else
                                  _fallbackBadge(isUrdu ? "ترجمہ دستیاب نہیں ہے" : "Translation unavailable", isDark),

                                const SizedBox(height: 22),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(isUrdu ? "حوالہ: ${widget.displayName} / حدیث $hNo" : "Ref: ${widget.displayName} / No. $hNo", style: GoogleFonts.poppins(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade600, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 8),
                                    _statusBadge(status, isDark),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text("Digital Islamic Hub", style: GoogleFonts.poppins(fontSize: 8, color: Colors.grey.withValues(alpha: 0.4))),
                                    const SizedBox(width: 5),
                                    const CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Colors.white,
                                      backgroundImage: AssetImage('assets/images/islamic_logo.png'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 🚫 OVERLAY ICONS (Excluded from RepaintBoundary)
                        Positioned(
                          top: 15,
                          right: 15,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share_outlined, color: Colors.blueAccent, size: 22),
                                onPressed: () => _shareHadith(_shareKeys[keyIndex]!, "Hadith $hNo - ${widget.displayName}\nShared via Digital Islamic Hub"),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                                onPressed: () async {
                                  await _bookmarkService.toggleHadithBookmark(
                                    collection: widget.collectionName,
                                    hadithNo: h['hadith_no'],
                                    lang: isUrdu ? 'ur' : 'en',
                                    textAr: h['text_ar'] ?? '',
                                    textTrans: isUrdu ? h['text_ur'] : h['text_en'],
                                  );
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _fallbackBadge(String text, bool isDark) {
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100, borderRadius: BorderRadius.circular(15)), child: Text(text, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade600)));
  }

  Widget _statusBadge(String status, bool isDark) {
    bool isSahih = status.contains("Sahih") || status.contains("صحیح");
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: isSahih ? Colors.teal.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSahih ? Colors.teal.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3))), child: Text(status, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: isSahih ? (isDark ? Colors.tealAccent : Colors.teal.shade700) : (isDark ? Colors.amberAccent : Colors.amber.shade900))));
  }
}
