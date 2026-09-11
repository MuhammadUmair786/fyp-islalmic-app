import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../core/database/db_helper.dart';
import '../models/surah_model.dart';
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';

class AyahDetailScreen extends StatefulWidget {
  final int surahNo;
  final int initialAyah;
  const AyahDetailScreen({super.key, required this.surahNo, this.initialAyah = 1});

  @override
  State<AyahDetailScreen> createState() => _AyahDetailScreenState();
}

class _AyahDetailScreenState extends State<AyahDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final BookmarkService _bookmarkService = BookmarkService();
  final ScrollController _scrollController = ScrollController();
  int? _playingAyahId;
  late Future<List<Map<String, dynamic>>> _ayahsFuture;

  final Map<int, GlobalKey> _shareKeys = {};

  String _selectedQariPath = "Abdul_Basit_Murattal_64kbps";
  final List<Map<String, String>> _qaris = [
    {"name": "Abdul Basit", "path": "Abdul_Basit_Murattal_64kbps"},
    {"name": "Mishary Alafasy", "path": "Alafasy_128kbps"},
    {"name": "Abdurrahman Sudais", "path": "Abdurrahmaan_As-Sudais_192kbps"},
  ];

  @override
  void initState() {
    super.initState();
    _ayahsFuture = DBHelper.getAyahsBySurah(widget.surahNo);
    _saveLastRead(widget.surahNo, widget.initialAyah);

    if (widget.initialAyah > 1) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _scrollToAyah(widget.initialAyah);
      });
    }
  }

  void _scrollToAyah(int ayahNo) {
    if (_scrollController.hasClients) {
      double offset = (ayahNo - 1) * 450.0; 
      _scrollController.animateTo(
        offset,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveLastRead(int surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', surah);
    await prefs.setInt('last_ayah', ayah);
  }

  String _forceCleanBismillah(String text) {
    if (text.isEmpty) return "";
    final bismillahPattern = RegExp(
      r'^(بِسْمِ\s+اللَّهِ\s+الرَّحْمَٰنِ\s+الرَّحِيمِ|بِسْمِ\s+ٱللَّهِ\s+ٱلرَّحْمَٰنِ\s+ٱلرَّحِيمِ|بِسمِ\s+اللَّهِ\s+الرَّحمنِ\s+الرَّحیمِ|بِسْمِ\s+اللهِ\s+الرَّحْمٰنِ\s+الرَّحِيْمِ|﷽)', 
      caseSensitive: false
    );
    String cleaned = text.trim();
    if (bismillahPattern.hasMatch(cleaned)) {
      cleaned = cleaned.replaceFirst(bismillahPattern, "").trim();
    }
    while (cleaned.isNotEmpty && RegExp(r'^[\s\u0610-\u061A\u06D6-\u06ED]').hasMatch(cleaned)) {
      cleaned = cleaned.substring(1).trim();
    }
    return cleaned;
  }

  Future<void> _playAyahAudio(int surah, int ayah, int globalId) async {
    try {
      if (_playingAyahId == globalId) {
        await _audioPlayer.stop();
        setState(() => _playingAyahId = null);
        return;
      }
      setState(() => _playingAyahId = globalId);
      String s = surah.toString().padLeft(3, '0');
      String a = ayah.toString().padLeft(3, '0');
      String url = "https://www.everyayah.com/data/$_selectedQariPath/$s$a.mp3";
      await _audioPlayer.play(UrlSource(url));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingAyahId = null);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _playingAyahId = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Audio not available")));
      }
    }
  }

  Future<void> _shareAyah(GlobalKey key, String text) async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      final RenderRepaintBoundary? boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      var pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final String fileName = 'ayah_${DateTime.now().millisecondsSinceEpoch}.png';
      final imagePath = await File('${directory.path}/$fileName').create();
      await imagePath.writeAsBytes(pngBytes);
      await Share.shareXFiles([XFile(imagePath.path)], text: text);
    } catch (e) {
      debugPrint("Share Error: $e");
    }
  }

  void _showQariSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Reciter (Qari)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 15),
              ..._qaris.map((qari) {
                bool isSelected = _selectedQariPath == qari['path'];
                return ListTile(
                  leading: Icon(Icons.mic_external_on, color: isSelected ? AppTheme.accentGreen : Colors.grey),
                  title: Text(qari['name']!, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : Colors.black87)),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.accentGreen) : null,
                  onTap: () {
                    setState(() {
                      _selectedQariPath = qari['path']!;
                      _audioPlayer.stop();
                      _playingAyahId = null;
                    });
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Surah currentSurah = Surah.getSurahByNo(widget.surahNo);
    final size = MediaQuery.sizeOf(context);

    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final bool isUrdu = locale.languageCode == 'ur';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: FittedBox(
              child: Text(isUrdu ? "${currentSurah.nameAr} (${currentSurah.nameEn})" : "${currentSurah.nameEn} (${currentSurah.nameAr})", 
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            centerTitle: true,
            backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.mic_none_rounded, color: Colors.white),
                onPressed: _showQariSelector,
                tooltip: "Select Qari",
              ),
            ],
          ),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _ayahsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No Data Found"));

              List<Map<String, dynamic>> processedList = [];
              for (var row in snapshot.data!) {
                var map = Map<String, dynamic>.from(row);
                if (map['ayah_no'] == 1 && widget.surahNo != 9) {
                  String cleaned = _forceCleanBismillah(map['arabic_text'] ?? "");
                  if (cleaned.isEmpty) continue;
                  map['arabic_text'] = cleaned;
                  
                  String trans = (isUrdu ? map['urdu_trans'] : map['eng_trans']) ?? "";
                  if (trans.toLowerCase().startsWith("in the name of allah") || trans.contains("شروع اللہ کے نام سے")) {
                     String cleanedTrans = trans.replaceFirst(RegExp(r'^.*?(رحیم|Most Merciful|رحمان)\s*(۔|\.)?\s*', caseSensitive: false), "").trim();
                     if (isUrdu) map['urdu_trans'] = cleanedTrans; else map['eng_trans'] = cleanedTrans;
                  }
                }
                processedList.add(map);
              }

              return StreamBuilder<DocumentSnapshot>(
                stream: _bookmarkService.getBookmarksStream(),
                builder: (context, bSnapshot) {
                  List bookmarkedAyahIds = [];
                  if (bSnapshot.hasData && bSnapshot.data!.exists) {
                    var bData = bSnapshot.data!.data() as Map<String, dynamic>;
                    List bookmarks = bData['ayah_bookmarks_v2'] ?? [];
                    bookmarkedAyahIds = bookmarks.map((e) => e['id']).toList();
                  }

                  return NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollEndNotification) {
                        int currentAyah = (scrollNotification.metrics.pixels / 450).round() + 1;
                        if (currentAyah > 0 && currentAyah <= processedList.length) {
                           _saveLastRead(widget.surahNo, currentAyah);
                        }
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: processedList.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemBuilder: (context, index) {
                        Ayah ayah = Ayah.fromMap(processedList[index]);
                        _shareKeys[ayah.id] = _shareKeys[ayah.id] ?? GlobalKey();
                        bool isBookmarked = bookmarkedAyahIds.contains("ayah_${widget.surahNo}_${ayah.ayahNo}");
                        int displayAyahNo = index + 1;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              if (index == 0 && widget.surahNo != 9)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10, bottom: 25),
                                  child: FittedBox(
                                    child: Text("بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ", 
                                      textAlign: TextAlign.center, 
                                      style: GoogleFonts.scheherazadeNew(fontSize: 30, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ),

                              Stack(
                                children: [
                                  RepaintBoundary(
                                    key: _shareKeys[ayah.id],
                                    child: Container(
                                      padding: const EdgeInsets.all(22),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(color: isDark ? Colors.white10 : Colors.green.shade50),
                                        boxShadow: isDark ? [] : [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))
                                        ],
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
                                                child: Text(isUrdu ? "آیت $displayAyahNo" : "Ayah $displayAyahNo",
                                                    style: GoogleFonts.poppins(
                                                      color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight, 
                                                      fontWeight: FontWeight.bold, fontSize: 12
                                                    )),
                                              ),
                                              const SizedBox(width: 80), // Space for absolute icons
                                            ],
                                          ),
                                          const SizedBox(height: 15),
                                          Text(ayah.arabicText, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: GoogleFonts.scheherazadeNew(fontSize: size.width > 600 ? 30 : 26, height: 1.6, fontWeight: FontWeight.w500, color: isDark ? Colors.white : AppTheme.primaryLight, shadows: isDark ? [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 2, offset: const Offset(1, 1))] : [])),
                                          const SizedBox(height: 20),
                                          Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, thickness: 0.8),
                                          const SizedBox(height: 10),
                                          Text(isUrdu ? ayah.urduTrans : ayah.engTrans, 
                                              textAlign: isUrdu ? TextAlign.right : TextAlign.left, 
                                              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr, 
                                              style: isUrdu 
                                                ? GoogleFonts.notoNastaliqUrdu(fontSize: 15, color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87, height: 2.2)
                                                : GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87, height: 1.5)),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Text("Digital Islamic Hub", style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey.withValues(alpha: 0.5))),
                                              const SizedBox(width: 8),
                                              const CircleAvatar(
                                                radius: 9,
                                                backgroundColor: Colors.white,
                                                backgroundImage: AssetImage('assets/images/islamic_logo.png'),
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
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(_playingAyahId == ayah.id ? Icons.stop_circle : Icons.play_circle_fill, color: AppTheme.accentGreen, size: 28),
                                          onPressed: () => _playAyahAudio(widget.surahNo, ayah.ayahNo, ayah.id),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.share_outlined, color: Colors.blueAccent, size: 22),
                                          onPressed: () => _shareAyah(_shareKeys[ayah.id]!, "Surah ${currentSurah.nameEn}, Ayah $displayAyahNo\nShared via Digital Islamic Hub"),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        IconButton(
                                          icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, size: 22, color: isBookmarked ? AppTheme.accentGreen : null),
                                          onPressed: () async {
                                            await _bookmarkService.toggleAyahBookmark(
                                              surahNo: widget.surahNo,
                                              ayahNo: ayah.ayahNo,
                                              surahName: currentSurah.nameEn,
                                              lang: isUrdu ? 'ur' : 'en',
                                              textAr: ayah.arabicText,
                                              textTrans: isUrdu ? ayah.urduTrans : ayah.engTrans,
                                            );
                                            setState(() {});
                                          },
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                                  title: Text(isUrdu ? "تفسیر دیکھیں" : "View Tafseer", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight)),
                                  children: [
                                    Container(
                                      constraints: const BoxConstraints(maxHeight: 250), 
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.black26 : Colors.grey[50], 
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                      ),
                                      child: Scrollbar(
                                        thumbVisibility: true, 
                                        thickness: 4,
                                        radius: const Radius.circular(10),
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(15),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Text(isUrdu ? "تفسیر (اردو):" : "Tafseer (English):", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight)),
                                              const SizedBox(height: 8),
                                              Text(isUrdu ? ayah.urduTafseer : (ayah.engTafseer.isNotEmpty ? ayah.engTafseer : "Commentary not available."), textAlign: isUrdu ? TextAlign.right : TextAlign.left, textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr, style: isUrdu ? GoogleFonts.notoNastaliqUrdu(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87, height: 2.0) : GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
}
