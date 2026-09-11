import 'package:flutter/material.dart';
import '../services/qaza_storage.dart';

class QazaRecordScreen extends StatefulWidget {
  const QazaRecordScreen({super.key});

  @override
  State<QazaRecordScreen> createState() => _QazaRecordScreenState();
}

class _QazaRecordScreenState extends State<QazaRecordScreen> {
  Map<String, int> _record = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    QazaStorage.qazaUpdated.addListener(_onStorageUpdated);
  }

  @override
  void dispose() {
    QazaStorage.qazaUpdated.removeListener(_onStorageUpdated);
    super.dispose();
  }

  void _onStorageUpdated() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final data = await QazaStorage.getAllQaza();
    if (mounted) {
      setState(() {
        _record = data;
        _loading = false;
      });
    }
  }

  Future<void> _decrement(String prayer) async {
    await QazaStorage.decrementQaza(prayer);
  }

  Future<void> _increment(String prayer) async {
    await QazaStorage.incrementQaza(prayer);
  }

  @override
  Widget build(BuildContext context) {
    final total = _record.values.fold(0, (sum, v) => sum + v);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qaza Namaz Tracker', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF2E7D32),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 3,
            color: isDark ? const Color(0xFF1E3A29) : Colors.green.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Total Qaza Namaz',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$total',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final prayer in QazaStorage.prayers) _buildRow(prayer, size),
        ],
      ),
    );
  }

  Widget _buildRow(String prayer, Size size) {
    final count = _record[prayer] ?? 0;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(prayer, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text('$count Qaza Remaining', style: TextStyle(color: count > 0 ? Colors.red.shade700 : Colors.grey)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 22,
              icon: const Icon(Icons.remove_circle, color: Color(0xFF2E7D32)),
              onPressed: count > 0 ? () => _decrement(prayer) : null,
            ),
            SizedBox(
              width: 30,
              child: Center(
                child: FittedBox(
                  child: Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            IconButton(
              iconSize: 22,
              icon: const Icon(Icons.add_circle, color: Colors.orange),
              onPressed: () => _increment(prayer),
            ),
          ],
        ),
      ),
    );
  }
}
