import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class DBHelper {
  static Database? _quranDb;
  static Database? _hadithDataDb;
  static Database? _hadithMetaDb;

  static final _quranLock = Completer<void>();
  static final _hadithDataLock = Completer<void>();
  static final _hadithMetaLock = Completer<void>();

  static bool _isQuranInitStarted = false;
  static bool _isHadithDataInitStarted = false;
  static bool _isHadithMetaInitStarted = false;

  // 1. QURAN DATABASE
  static Future<Database?> get db async {
    if (_quranDb != null && _quranDb!.isOpen) return _quranDb;
    if (!_isQuranInitStarted) {
      _isQuranInitStarted = true;
      try {
        _quranDb = await initDb("quran_final_authentic_v2.db", "quran_v501.db");
        _quranLock.complete();
      } catch (e) {
        _quranLock.completeError(e);
        _isQuranInitStarted = false;
      }
    }
    await _quranLock.future;
    return _quranDb;
  }

  // 2. HADITH DATA DATABASE
  static Future<Database?> get mainHadithDb async {
    if (_hadithDataDb != null && _hadithDataDb!.isOpen) return _hadithDataDb;
    if (!_isHadithDataInitStarted) {
      _isHadithDataInitStarted = true;
      try {
        _hadithDataDb = await initDb("hadiths_only.db", "hadith_data_v501.db");
        _hadithDataLock.complete();
      } catch (e) {
        _hadithDataLock.completeError(e);
        _isHadithDataInitStarted = false;
      }
    }
    await _hadithDataLock.future;
    return _hadithDataDb;
  }

  // 3. HADITH METADATA DATABASE
  static Future<Database?> get hadithMetaDb async {
    if (_hadithMetaDb != null && _hadithMetaDb!.isOpen) return _hadithMetaDb;
    if (!_isHadithMetaInitStarted) {
      _isHadithMetaInitStarted = true;
      try {
        _hadithMetaDb = await initDb("hadith_metadata.db", "hadith_meta_v501.db");
        _hadithMetaLock.complete();
      } catch (e) {
        _hadithMetaLock.completeError(e);
        _isHadithMetaInitStarted = false;
      }
    }
    await _hadithMetaLock.future;
    return _hadithMetaDb;
  }

  static Future<Database> initDb(String assetName, String localName) async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, localName);

    // Refresh for v501
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }

    debugPrint("📦 Initializing $assetName...");
    await Directory(dirname(path)).create(recursive: true);
    ByteData data = await rootBundle.load("assets/database/$assetName");
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(path).writeAsBytes(bytes, flush: true);

    return await openDatabase(path, readOnly: true);
  }

  static Future<String> _findTableName(Database db, List<String> hints) async {
    var tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    for (var hint in hints) {
      for (var t in tables) {
        String name = t['name'].toString().toLowerCase();
        if (name.contains(hint.toLowerCase())) return t['name'] as String;
      }
    }
    return tables.isNotEmpty ? tables.first['name'] as String : "";
  }

  static Future<String> _findColumnName(Database db, String tableName, List<String> hints) async {
    var result = await db.rawQuery("PRAGMA table_info($tableName)");
    for (var hint in hints) {
      for (var row in result) {
        String colName = row['name'].toString().toLowerCase();
        if (colName.contains(hint.toLowerCase())) return row['name'] as String;
      }
    }
    return hints.first;
  }

  // Helper for flexible collection slug variants
  static List<String> _getSlugVariants(String rawCollection) {
    String clean = rawCollection.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    List<String> variants = ['%$clean%'];
    if (clean.contains("tirmidhi") || clean.contains("tirmzi")) {
      variants.addAll(['%tirm%', '%jami%', '%jamiat%']);
    } else if (clean.contains("dawud") || clean.contains("daud") || clean.contains("abu")) {
      variants.addAll(['%dawu%', '%daud%', '%abi%', '%abu%']);
    } else if (clean.contains("bukhari")) {
      variants.addAll(['%bukhari%', '%sahih%bukhari%']);
    } else if (clean.contains("muslim")) {
      variants.addAll(['%muslim%', '%sahih%muslim%']);
    }
    return variants.toSet().toList();
  }

  // --- HADITH LOGIC ---
  static Future<List<Map<String, dynamic>>> getChaptersByBook(String collectionName) async {
    final metaDb = await hadithMetaDb;
    if (metaDb == null) return [];
    try {
      String tableName = await _findTableName(metaDb, ["meta", "topic", "chapter", "metadata"]);
      List<String> variants = _getSlugVariants(collectionName);

      String whereClause = variants.map((_) => "LOWER(collection_slug) LIKE ?").join(" OR ");
      whereClause += " OR " + variants.map((_) => "LOWER(book_name_en) LIKE ?").join(" OR ");

      String query = '''
        SELECT DISTINCT topic_id, MAX(topic_name_en) as topic_name_en, MAX(topic_name_ur) as topic_name_ur, 
        MIN(CAST(topic_start_no AS INTEGER)) as start_no, MAX(CAST(topic_end_no AS INTEGER)) as end_no, 
        MAX(CAST(total_hadiths_in_topic AS INTEGER)) as total_hadiths
        FROM $tableName 
        WHERE $whereClause
        GROUP BY topic_id ORDER BY CAST(topic_id AS INTEGER) ASC
      ''';

      var results = await metaDb.rawQuery(query, [...variants, ...variants]);

      if (results.isEmpty) {
        debugPrint("⚠️ No chapters found for $collectionName. Trying extraction fallback.");
        results = await metaDb.rawQuery("SELECT DISTINCT topic_id, topic_name_en, topic_name_ur, topic_start_no as start_no, topic_end_no as end_no FROM $tableName GROUP BY topic_id LIMIT 100");
      }

      return results;
    } catch (e) {
      debugPrint("❌ Chapter Load Error: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getHadithsByTopic({required String collectionName, required dynamic topicId}) async {
    final metaDb = await hadithMetaDb;
    final mainDb = await mainHadithDb;
    if (metaDb == null || mainDb == null) return [];

    try {
      String metaTable = await _findTableName(metaDb, ["meta", "topic", "metadata"]);
      String mainTable = await _findTableName(mainDb, ["hadith", "data", "hadiths"]);

      List<String> variants = _getSlugVariants(collectionName);

      String whereMeta = variants.map((_) => "LOWER(collection_slug) LIKE ?").join(" OR ");
      whereMeta += " OR " + variants.map((_) => "LOWER(book_name_en) LIKE ?").join(" OR ");

      // 1. Get metadata for this topic
      String metaQuery = 'SELECT hadith_no, status_en, status_ur FROM $metaTable WHERE ($whereMeta) AND CAST(topic_id AS TEXT) = CAST(? AS TEXT) ORDER BY CAST(hadith_no AS INTEGER) ASC';
      List<Map<String, dynamic>> metaResults = await metaDb.rawQuery(metaQuery, [...variants, ...variants, topicId]);

      // Fallback metadata query without collection_slug restriction if empty
      if (metaResults.isEmpty) {
        metaResults = await metaDb.rawQuery(
            'SELECT hadith_no, status_en, status_ur FROM $metaTable WHERE CAST(topic_id AS TEXT) = CAST(? AS TEXT) ORDER BY CAST(hadith_no AS INTEGER) ASC',
            [topicId]
        );
      }

      if (metaResults.isEmpty) return [];

      List<String> hadithNos = metaResults.map((e) => e['hadith_no'].toString()).toList();
      if (hadithNos.isEmpty) return [];

      String placeholders = List.filled(hadithNos.length, '?').join(',');

      // 2. Resolve Column Names Dynamically
      String numCol = await _findColumnName(mainDb, mainTable, ["hadith_number", "hadith_no", "hadith_id", "id"]);
      String arCol = await _findColumnName(mainDb, mainTable, ["text_arabic", "arabic_text", "text_ar", "arabic"]);
      String urCol = await _findColumnName(mainDb, mainTable, ["text_urdu", "urdu_text", "text_ur", "urdu"]);
      String enCol = await _findColumnName(mainDb, mainTable, ["text_english", "english_text", "text_en", "english"]);
      String slugCol = await _findColumnName(mainDb, mainTable, ["book_slug", "collection_slug", "collection", "slug"]);

      // 3. Get Hadith Text with flexible slug matching
      String slugWhereClause = variants.map((_) => "LOWER($slugCol) LIKE ?").join(" OR ");
      String mainQuery = '''
        SELECT $numCol as hadith_no, $arCol as text_ar, $urCol as text_ur, $enCol as text_en 
        FROM $mainTable 
        WHERE $numCol IN ($placeholders)
        AND ($slugWhereClause)
        ORDER BY CAST($numCol AS INTEGER) ASC
      ''';

      List<Map<String, dynamic>> mainResults = await mainDb.rawQuery(mainQuery, [...hadithNos, ...variants]);

      // Direct fallback by hadith_number list if slug condition fails
      if (mainResults.isEmpty) {
        debugPrint("⚠️ Slug match failed for $collectionName. Falling back to hadith_number list query.");
        mainResults = await mainDb.rawQuery(
            'SELECT $numCol as hadith_no, $arCol as text_ar, $urCol as text_ur, $enCol as text_en FROM $mainTable WHERE $numCol IN ($placeholders) ORDER BY CAST($numCol AS INTEGER) ASC',
            hadithNos
        );
      }

      Map<String, Map<String, dynamic>> metaMap = {for (var m in metaResults) m['hadith_no'].toString(): m};

      return mainResults.map((item) {
        String hNoStr = item['hadith_no'].toString();
        var meta = metaMap[hNoStr] ?? {};
        return {
          'hadith_no': hNoStr,
          'text_ar': item['text_ar'] ?? '',
          'text_ur': item['text_ur'] ?? '',
          'text_en': item['text_en'] ?? '',
          'status_en': meta['status_en'] ?? 'Sahih',
          'status_ur': meta['status_ur'] ?? 'صحیح',
        };
      }).toList();
    } catch (e) {
      debugPrint("❌ Hadith Fetch Error: $e");
      return [];
    }
  }

  // --- QURAN LOGIC ---
  static Future<List<Map<String, dynamic>>> getSurahList() async {
    final dbClient = await db;
    if (dbClient == null) return [];
    try {
      return await dbClient.rawQuery("SELECT DISTINCT surah_no FROM quran_data ORDER BY surah_no ASC");
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAyahsBySurah(int surahNo) async {
    final dbClient = await db;
    if (dbClient == null) return [];
    try {
      var results = await dbClient.query('quran_data', where: 'surah_no = ?', whereArgs: [surahNo], orderBy: 'ayah_no ASC');
      return results.map((row) {
        var map = Map<String, dynamic>.from(row);
        map['urdu_tafseer'] = map['tafseer_urdu'] ?? map['urdu_tafseer'];
        map['eng_tafseer'] = map['tafseer_english'] ?? map['eng_tafseer'];
        map['urdu_trans'] = map['urdu_translation'] ?? map['urdu_trans'];
        map['eng_trans'] = map['english_translation'] ?? map['eng_trans'];
        return map;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getAyahByReference(int surahNo, int ayahNo) async {
    final dbClient = await db;
    if (dbClient == null) return null;
    try {
      var results = await dbClient.query('quran_data', 
        where: 'surah_no = ? AND ayah_no = ?', 
        whereArgs: [surahNo, ayahNo], 
        limit: 1);
      
      if (results.isNotEmpty) {
        var map = Map<String, dynamic>.from(results.first);
        map['urdu_tafseer'] = map['tafseer_urdu'] ?? map['urdu_tafseer'];
        map['eng_tafseer'] = map['tafseer_english'] ?? map['eng_tafseer'];
        map['urdu_trans'] = map['urdu_translation'] ?? map['urdu_trans'];
        map['eng_trans'] = map['english_translation'] ?? map['eng_trans'];
        return map;
      }
    } catch (e) {
      debugPrint("Ayah Reference Error: $e");
    }
    return null;
  }
}