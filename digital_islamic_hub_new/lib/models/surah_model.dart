class Surah {
  final int surahNo;
  final String nameEn;
  final String nameAr;
  final int totalAyahs;
  final String type; // Makki or Madni

  Surah({
    required this.surahNo,
    required this.nameEn,
    required this.nameAr,
    required this.totalAyahs,
    required this.type,
  });

  static Surah getSurahByNo(int no) {
    return Surah(
      surahNo: no,
      nameEn: surahNamesEn[no - 1],
      nameAr: surahNamesAr[no - 1],
      totalAyahs: surahAyahCounts[no - 1],
      type: surahTypes[no - 1],
    );
  }

  // Sample data (Maine starting ki lists di hain, aap isi tarah 114 tak fill kar sakti hain)
  static const List<int> surahAyahCounts = [7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 28, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6];

  static const List<String> surahTypes = ["Makki", "Madni", "Madni", "Madni", "Madni", "Makki", "Makki", "Madni", "Madni", "Makki", "Makki", "Makki", "Madni", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Madni", "Makki", "Madni", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Madni", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Madni", "Madni", "Madni", "Makki", "Makki", "Makki", "Makki", "Makki", "Madni", "Makki", "Madni", "Madni", "Madni", "Madni", "Madni", "Madni", "Madni", "Madni", "Madni", "Madni", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Madni", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Madni", "Madni", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Makki", "Madni", "Makki", "Makki", "Makki", "Makki"];

  static const List<String> surahNamesEn = ["Al-Fatiha", "Al-Baqarah", "Al-Imran", "An-Nisa", "Al-Ma'idah", "Al-An'am", "Al-A'raf", "Al-Anfal", "At-Tawbah", "Yunus", "Hud", "Yusuf", "Ar-Ra'd", "Ibrahim", "Al-Hijr", "An-Nahl", "Al-Isra", "Al-Kahf", "Maryam", "Ta-Ha", "Al-Anbiya", "Al-Hajj", "Al-Mu'minun", "An-Nur", "Al-Furqan", "Ash-Shu'ara", "An-Naml", "Al-Qasas", "Al-Ankabut", "Ar-Rum", "Luqman", "As-Sajdah", "Al-Ahzab", "Saba", "Fatir", "Ya-Sin", "As-Saffat", "Sad", "Az-Zumar", "Ghafir", "Fussilat", "Ash-Shura", "Az-Zukhruf", "Ad-Dukhan", "Al-Jathiyah", "Al-Ahqaf", "Muhammad", "Al-Fath", "Al-Hujurat", "Qaf", "Adh-Dhariyat", "At-Tur", "An-Najm", "Al-Qamar", "Ar-Rahman", "Al-Waqi'ah", "Al-Hadid", "Al-Mujadila", "Al-Hashr", "Al-Mumtahina", "As-Saff", "Al-Jumu'ah", "Al-Munafiqun", "At-Taghabun", "At-Talaq", "At-Tahrim", "Al-Mulk", "Al-Qalam", "Al-Haqqah", "Al-Ma'arij", "Nuh", "Al-Jinn", "Al-Muzzammil", "Al-Muddathir", "Al-Qiyamah", "Al-Insan", "Al-Mursalat", "An-Naba", "An-Nazi'at", "'Abasa", "At-Takwir", "Al-Infitar", "Al-Mutaffifin", "Al-Inshiqaq", "Al-Buruj", "At-Tariq", "Al-A'la", "Al-Ghashiyah", "Al-Fajr", "Al-Balad", "Ash-Shams", "Al-Layl", "Ad-Duha", "Ash-Sharh", "At-Tin", "Al-'Alaq", "Al-Qadr", "Al-Bayyinah", "Az-Zalzalah", "Al-'Adiyat", "Al-Qari'ah", "At-Takathur", "Al-'Asr", "Al-Humazah", "Al-Fil", "Quraysh", "Al-Ma'un", "Al-Kawthar", "Al-Kafirun", "An-Nasr", "Al-Masad", "Al-Ikhlas", "Al-Falaq", "An-Nas"];

  static const List<String> surahNamesAr = ["الفاتحة", "البقرة", "آل عمران", "النساء", "المائدة", "الأنعام", "الأعراف", "الأنفال", "التوبة", "يونس", "هود", "يوسف", "الرعد", "إبراهيم", "الحجر", "النحل", "الإسراء", "الكهف", "مريم", "طه", "الأنبياء", "الحج", "المؤمنون", "النور", "الفرقان", "الشعراء", "النمل", "القصص", "العنكبوت", "الروم", "لقمان", "السجدة", "الأحزاب", "سبأ", "فاطر", "يس", "الصافات", "ص", "الزمر", "غافر", "فصلت", "الشورى", "الزخرف", "الدخان", "الجاثية", "الأحقاف", "محمد", "الفتح", "الحجرات", "ق", "الذاريات", "الطور", "النجم", "القمر", "الرحمن", "الواقعة", "الحديد", "المجادلة", "الحشر", "الممتحنة", "الصف", "الجمعة", "المنافقون", "التغابن", "الطلاق", "التحريم", "الملك", "القلم", "الحاقة", "المعارج", "نوح", "الجن", "المزمل", "المدثر", "القيامة", "الإنسان", "المرسلات", "النبأ", "النازعات", "عبس", "التكوير", "الانفطار", "المطففين", "الانشقاق", "البروج", "الطارق", "الأعلى", "الغاشية", "الفجر", "البلد", "الشمس", "الليل", "الضحى", "الشرح", "التين", "العلق", "القدر", "البينة", "الزلزلة", "العاديات", "القارعة", "التكاثر", "العصر", "الهمزة", "الفيل", "قريش", "الماعون", "الكوثر", "الكافرون", "النصر", "المسد", "الإخلاص", "الفلق", "الناس"];
}

class Ayah {
  final int id;
  final int ayahNo;
  final String arabicText;
  final String urduTrans;
  final String urduTafseer;
  final String engTrans;
  final String engTafseer;

  Ayah({required this.id, required this.ayahNo, required this.arabicText, required this.urduTrans, required this.urduTafseer, required this.engTrans, required this.engTafseer});

  factory Ayah.fromMap(Map<String, dynamic> map) {
    return Ayah(
      id: map['id'] ?? 0,
      ayahNo: map['ayah_no'],
      arabicText: map['arabic_text'] ?? '',
      urduTrans: map['urdu_trans'] ?? '',
      urduTafseer: map['urdu_tafseer'] ?? '',
      engTrans: map['eng_trans'] ?? '',
      engTafseer: map['eng_tafseer'] ?? '',
    );
  }
}