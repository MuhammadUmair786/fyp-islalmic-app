import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../services/qaza_notification_service.dart';
import 'qaza_namaz_tracker.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Map<String, bool> notificationsActive = {
    "Fajr": false,
    "Dhuhr": false,
    "Asr": false,
    "Maghrib": false,
    "Isha": false,
  };

  PrayerTimes? _prayerTimes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    PrayerService.prayerTimesNotifier.addListener(_onPrayerTimesUpdated);
    _initData();
    // 🚀 Request permissions without blocking the data loading
    Future.microtask(() => NotificationService.requestPermissions());
  }

  void _onPrayerTimesUpdated() {
    if (mounted) {
      setState(() {
        _prayerTimes = PrayerService.prayerTimesNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    PrayerService.prayerTimesNotifier.removeListener(_onPrayerTimesUpdated);
    super.dispose();
  }

  Future<void> _initData() async {
    await Future.wait([
      _loadSettings(),
      _loadPrayerTimes(),
    ]);
    if (mounted) {
      _autoScheduleActiveReminders();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPrayerTimes() async {
    final pt = await PrayerService.getPrayerTimes();
    if (mounted && pt != null) {
      setState(() {
        _prayerTimes = pt;
      });
      // 🚀 Non-blocking background scheduling
      QazaNotificationService.scheduleQazaChecks(pt);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      notificationsActive = {
        "Fajr": prefs.getBool("Fajr") ?? false,
        "Dhuhr": prefs.getBool("Dhuhr") ?? false,
        "Asr": prefs.getBool("Asr") ?? false,
        "Maghrib": prefs.getBool("Maghrib") ?? false,
        "Isha": prefs.getBool("Isha") ?? false,
      };
    });
  }

  void _autoScheduleActiveReminders() {
    if (_prayerTimes == null) return;

    final Map<String, DateTime> mapTimes = {
      "Fajr": _prayerTimes!.fajr,
      "Dhuhr": _prayerTimes!.dhuhr,
      "Asr": _prayerTimes!.asr,
      "Maghrib": _prayerTimes!.maghrib,
      "Isha": _prayerTimes!.isha,
    };

    mapTimes.forEach((prayerName, prayerTime) {
      if (notificationsActive[prayerName] == true) {
        NotificationService.schedulePrayerNotification(
          prayerName.hashCode,
          prayerName,
          prayerTime,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF001F1A) : Colors.white,
      appBar: AppBar(
        title: const Text("Prayer Schedule",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF001F1A) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => NotificationService.testInstant(),
            tooltip: 'Test Azan Notification',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : (_prayerTimes == null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off, size: 42, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load prayer times.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check location permission and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _isLoading = true);
                        _initData();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildExtraTimesCard(
              _prayerTimes!.sunrise,
              _prayerTimes!.dhuhr
                  .subtract(const Duration(minutes: 10)),
              _prayerTimes!.maghrib,
              isDark,
            ),
            const SizedBox(height: 20),
            _prayerTile(
                "Fajr", _prayerTimes!.fajr, Icons.wb_twilight, isDark),
            _prayerTile(
                "Dhuhr", _prayerTimes!.dhuhr, Icons.wb_sunny, isDark),
            _prayerTile(
                "Asr", _prayerTimes!.asr, Icons.cloud_queue, isDark),
            _prayerTile("Maghrib", _prayerTimes!.maghrib,
                Icons.nightlight_round, isDark),
            _prayerTile(
                "Isha", _prayerTimes!.isha, Icons.dark_mode, isDark),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Qaza Namaz Record'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const QazaRecordScreen()));
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraTimesCard(
      DateTime sunrise, DateTime zawal, DateTime sunset, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color:
        isDark ? Colors.white.withValues(alpha: 0.1) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white24 : Colors.orange.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
              child: _extraItem("Sunrise", sunrise, Icons.wb_sunny_outlined,
                  Colors.orange, isDark)),
          Container(
              width: 1,
              height: 30,
              color: isDark ? Colors.white10 : Colors.orange.shade100),
          Expanded(
              child: _extraItem("Zawal", zawal, Icons.warning_amber_rounded,
                  Colors.redAccent, isDark)),
          Container(
              width: 1,
              height: 30,
              color: isDark ? Colors.white10 : Colors.orange.shade100),
          Expanded(
              child: _extraItem("Sunset", sunset, Icons.nights_stay_outlined,
                  Colors.blueGrey, isDark)),
        ],
      ),
    );
  }

  Widget _extraItem(String l, DateTime t, IconData i, Color c, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, color: c, size: 18),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(l,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(DateFormat.jm().format(t),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
        ),
      ],
    );
  }

  Widget _prayerTile(String name, DateTime time, IconData icon, bool isDark) {
    bool isNotify = notificationsActive[name] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: isNotify ? const Color(0xFF2E7D32) : Colors.transparent),
      ),
      child: ListTile(
        leading:
        Icon(icon, color: isNotify ? const Color(0xFF2E7D32) : Colors.grey),
        title: Text(name,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(DateFormat.jm().format(time),
            style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54)),
        trailing: Switch(
          value: isNotify,
          activeTrackColor: const Color(0xFF2E7D32).withValues(alpha: 0.5),
          activeThumbColor: const Color(0xFF2E7D32),
          onChanged: (v) async {
            final prefs = await SharedPreferences.getInstance();
            setState(() {
              notificationsActive[name] = v;
            });
            await prefs.setBool(name, v);

            if (v) {
              await NotificationService.schedulePrayerNotification(
                  name.hashCode, name, time);
            } else {
              await NotificationService.cancelNotification(name.hashCode);
            }
          },
        ),
      ),
    );
  }
}