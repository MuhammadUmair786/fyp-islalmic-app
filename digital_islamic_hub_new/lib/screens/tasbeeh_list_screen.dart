import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'tasbeeh_counter_screen.dart';
import '../theme/app_theme.dart';

class TasbeehListScreen extends StatefulWidget {
  const TasbeehListScreen({super.key});

  @override
  State<TasbeehListScreen> createState() => _TasbeehListScreenState();
}

class _TasbeehListScreenState extends State<TasbeehListScreen> {
  List<Map<String, dynamic>> _zikars = [
    {"name": "SubhanAllah", "goal": 33, "count": 0},
    {"name": "Alhamdulillah", "goal": 33, "count": 0},
    {"name": "Allahu Akbar", "goal": 34, "count": 0},
  ];

  @override
  void initState() {
    super.initState();
    _loadZikars();
  }

  _loadZikars() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedData = prefs.getString('zikar_list');
    if (savedData != null) {
      setState(() {
        _zikars = List<Map<String, dynamic>>.from(json.decode(savedData));
      });
    }
  }

  _saveZikars() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zikar_list', json.encode(_zikars));
  }

  void _addNewZikar() {
    String name = "";
    int goal = 33;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: isDark ? AppTheme.primaryDark : Colors.white,
        title: Text("Add New Zikar", style: TextStyle(color: isDark ? Colors.white : AppTheme.primaryLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Zikar Name", 
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                hintText: "e.g. Astaghfirullah",
                hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
              ),
              onChanged: (val) => name = val,
            ),
            const SizedBox(height: 10),
            TextField(
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Target/Goal",
                labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
              keyboardType: TextInputType.number,
              onChanged: (val) => goal = int.tryParse(val) ?? 33,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("Cancel", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
              foregroundColor: isDark ? AppTheme.primaryDark : Colors.white,
            ),
            onPressed: () {
              if (name.isNotEmpty) {
                setState(() {
                  _zikars.add({"name": name, "goal": goal, "count": 0});
                });
                _saveZikars();
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("My Tasbeeh", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _zikars.length,
        itemBuilder: (context, index) {
          final zikar = _zikars[index];
          double progress = zikar['count'] / zikar['goal'];

          return Card(
            elevation: isDark ? 0 : 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: isDark ? Colors.white.withAlpha(12) : Colors.white,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.track_changes, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
              title: Text(zikar['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress > 1.0 ? 1.0 : progress,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                    color: progress >= 1.0 ? AppTheme.accentGreen : (isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
                  ),
                  const SizedBox(height: 4),
                  Text("${zikar['count']} / ${zikar['goal']}", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
              trailing: Icon(Icons.chevron_right, color: isDark ? AppTheme.accentGreen : AppTheme.primaryLight),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TasbeehCounterScreen(
                      zikar: zikar,
                      index: index,
                      onUpdate: (newCount) {
                        setState(() {
                          _zikars[index]['count'] = newCount;
                        });
                        _saveZikars();
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewZikar,
        backgroundColor: isDark ? AppTheme.accentGreen : AppTheme.primaryLight,
        child: Icon(Icons.add, color: isDark ? AppTheme.primaryDark : Colors.white),
      ),
    );
  }
}