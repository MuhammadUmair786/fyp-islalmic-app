import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class BookmarkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference? get _userDoc {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  Stream<DocumentSnapshot> getBookmarksStream() {
    final userDoc = _userDoc;
    if (userDoc == null) return const Stream.empty();
    return userDoc.snapshots();
  }

  Future<void> toggleHadithBookmark({
    required String collection,
    required dynamic hadithNo,
    required String lang,
    required String textAr,
    required String textTrans,
  }) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    final String bookmarkId = "${collection.toLowerCase()}_$hadithNo";

    try {
      final snap = await userDoc.get();
      List<dynamic> bookmarks = [];
      if (snap.exists) {
        var data = snap.data() as Map<String, dynamic>;
        bookmarks = data['hadith_bookmarks_v2'] ?? [];
      }

      int index = bookmarks.indexWhere((e) => e['id'] == bookmarkId);

      if (index != -1) {
        bookmarks.removeAt(index);
      } else {
        bookmarks.add({
          'id': bookmarkId,
          'collection': collection,
          'hadithNo': hadithNo,
          'lang': lang,
          'textAr': textAr,
          'textTrans': textTrans,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      await userDoc.set({'hadith_bookmarks_v2': bookmarks}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Hadith Bookmark Error: $e");
    }
  }

  Future<void> toggleAyahBookmark({
    required int surahNo,
    required int ayahNo,
    required String surahName,
    required String lang,
    required String textAr,
    required String textTrans,
  }) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;

    final String bookmarkId = "ayah_${surahNo}_$ayahNo";

    try {
      final snap = await userDoc.get();
      List<dynamic> bookmarks = [];
      if (snap.exists) {
        var data = snap.data() as Map<String, dynamic>;
        bookmarks = data['ayah_bookmarks_v2'] ?? [];
      }

      int index = bookmarks.indexWhere((e) => e['id'] == bookmarkId);

      if (index != -1) {
        bookmarks.removeAt(index);
      } else {
        bookmarks.add({
          'id': bookmarkId,
          'surahNo': surahNo,
          'ayahNo': ayahNo,
          'surahName': surahName,
          'lang': lang,
          'textAr': textAr,
          'textTrans': textTrans,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      await userDoc.set({'ayah_bookmarks_v2': bookmarks}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Ayah Bookmark Error: $e");
    }
  }

  Future<void> deleteBookmark(String id, bool isHadith) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;
    String field = isHadith ? 'hadith_bookmarks_v2' : 'ayah_bookmarks_v2';
    
    try {
      final snap = await userDoc.get();
      if (!snap.exists) return;
      List<dynamic> bookmarks = (snap.data() as Map<String, dynamic>)[field] ?? [];
      bookmarks.removeWhere((e) => e['id'] == id);
      await userDoc.update({field: bookmarks});
    } catch (e) {
      debugPrint("Delete Bookmark Error: $e");
    }
  }

  Future<void> toggleSurahFavorite(int surahNo) async {
    final userDoc = _userDoc;
    if (userDoc == null) return;
    try {
      final snap = await userDoc.get();
      List<dynamic> favorites = [];
      if (snap.exists) {
        var data = snap.data() as Map<String, dynamic>;
        favorites = data['surah_favorites'] ?? [];
      }
      if (favorites.contains(surahNo)) {
        favorites.remove(surahNo);
      } else {
        favorites.add(surahNo);
      }
      await userDoc.set({'surah_favorites': favorites}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Surah Favorite Error: $e");
    }
  }
}
