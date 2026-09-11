import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SafarDuaScreen extends StatefulWidget {
  const SafarDuaScreen({super.key});

  @override
  State<SafarDuaScreen> createState() => _SafarDuaScreenState();
}

class _SafarDuaScreenState extends State<SafarDuaScreen> {
  bool isAutoDetectOn = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color primaryColor = isDark ? AppTheme.accentGreen : AppTheme.primaryLight;
    final Color accentColor = isDark ? AppTheme.accentGreen : AppTheme.primaryLight;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color cardColor = isDark ? Colors.white.withAlpha(15) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Safar ki Dua",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            _buildFeatureToggle(isDark, cardColor, primaryColor),

            const SizedBox(height: 25),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10)
                  )
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.auto_awesome, color: accentColor.withOpacity(0.5), size: 40),
                  const SizedBox(height: 20),

                  Text(
                    "سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَى رَبِّنَا لَمُنْقَلِبُونَ",
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.8,
                      color: isDark ? Colors.white : AppTheme.primaryLight,
                    ),
                  ),

                  const SizedBox(height: 30),
                  Divider(color: accentColor.withOpacity(0.1), thickness: 1.5),
                  const SizedBox(height: 25),

                  _translationBlock(
                    "اردو ترجمہ",
                    "پاک ہے وہ ذات جس نے ہمارے لیے اسے مسخر کر دیا، حالانکہ ہم اسے قابو میں لانے کی طاقت نہیں رکھتے تھے۔ اور بے شک ہم اپنے رب ہی کی طرف پلٹنے والے ہیں۔",
                    accentColor,
                    textColor,
                    isDark,
                    isUrdu: true,
                  ),

                  const SizedBox(height: 30),

                  _translationBlock(
                    "English Translation",
                    "Glory be to Him Who has brought this [vehicle] under our control, though we were unable to control it ourselves. And indeed, to our Lord we will surely return.",
                    accentColor,
                    textColor,
                    isDark,
                    isUrdu: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureToggle(bool isDark, Color cardColor, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withOpacity(0.15),
            child: Icon(Icons.speed, color: primary, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Smart Detection",
                    style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const Text("Show popup during travel",
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: isAutoDetectOn,
            activeColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
            onChanged: (v) => setState(() => isAutoDetectOn = v),
          ),
        ],
      ),
    );
  }

  Widget _translationBlock(String title, String content, Color accent, Color textCol, bool isDark, {required bool isUrdu}) {
    return Column(
      crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: isUrdu ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isUrdu) Icon(Icons.language, size: 14, color: accent),
            const SizedBox(width: 5),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                    letterSpacing: 0.5
                )),
            if (isUrdu) const SizedBox(width: 5),
            if (isUrdu) Icon(Icons.menu_book, size: 14, color: accent),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content,
          textAlign: isUrdu ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: isDark ? Colors.white.withOpacity(0.8) : Colors.black87,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}