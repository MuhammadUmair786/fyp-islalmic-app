import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/dnd_service.dart';
import 'masjid_map_screen.dart';

class MasjidSettingsScreen extends StatefulWidget {
  final String? initialMosqueName;
  final double? initialLatitude;
  final double? initialLongitude;

  const MasjidSettingsScreen({
    Key? key,
    this.initialMosqueName,
    this.initialLatitude,
    this.initialLongitude,
  }) : super(key: key);

  @override
  State<MasjidSettingsScreen> createState() => _MasjidSettingsScreenState();
}

class _MasjidSettingsScreenState extends State<MasjidSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();

  bool _isAutoSilentEnabled = true;
  double _geofenceRadius = 100.0;
  bool _isLoading = false;

  double? _selectedLat;
  double? _selectedLng;

  List<Map<String, dynamic>> _savedMosques = [];
  Map<String, dynamic>? _activeMosque;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String get _docId => FirebaseAuth.instance.currentUser?.uid ?? 'user_masjid_config';

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLatitude;
    _selectedLng = widget.initialLongitude;
    _nameController.text = widget.initialMosqueName ?? '';
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      DocumentSnapshot doc = await _firestore
          .collection('masjid_settings')
          .doc(_docId)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        _isAutoSilentEnabled = data['is_auto_silent_enabled'] ?? true;
        _geofenceRadius = (data['geofence_radius'] as num?)?.toDouble() ?? 100.0;

        List<dynamic> rawList = data['saved_mosques'] ?? [];
        _savedMosques = rawList.map((item) => Map<String, dynamic>.from(item)).toList();

        if (data['active_mosque'] != null) {
          _activeMosque = Map<String, dynamic>.from(data['active_mosque']);
        }
      }

      // If came from Map with a newly selected location, auto-populate
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _selectedLat = widget.initialLatitude;
        _selectedLng = widget.initialLongitude;
        if (_nameController.text.isEmpty) {
          _nameController.text = widget.initialMosqueName ?? 'Selected Mosque';
        }
      } else if (_activeMosque != null) {
        _selectedLat = (_activeMosque!['lat'] as num).toDouble();
        _selectedLng = (_activeMosque!['lng'] as num).toDouble();
        _nameController.text = _activeMosque!['name'] ?? '';
      }
    } catch (e) {
      debugPrint("Error loading mosque data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Save settings, handle immediate silent & start background service
  Future<void> _saveAllSettings() async {
    final mosqueName = _nameController.text.trim();
    if (mosqueName.isEmpty || _selectedLat == null || _selectedLng == null) {
      _showSnackBar("Please select a mosque location first!", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Permission check
      bool hasPermission = await DndService.isNotificationPolicyAccessGranted();
      if (!hasPermission && _isAutoSilentEnabled) {
        await DndService.openNotificationPolicySettings();
        _showSnackBar("Please allow Do Not Disturb permission in settings.", Colors.orange);
        setState(() => _isLoading = false);
        return;
      }

      final newMosque = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': mosqueName,
        'lat': _selectedLat,
        'lng': _selectedLng,
      };

      // Add to list if not existing
      bool exists = _savedMosques.any((element) =>
      element['lat'] == _selectedLat && element['lng'] == _selectedLng);

      if (!exists) {
        _savedMosques.add(newMosque);
      }
      _activeMosque = newMosque;

      // Update Firestore
      await _firestore.collection('masjid_settings').doc(_docId).set({
        'is_auto_silent_enabled': _isAutoSilentEnabled,
        'geofence_radius': _geofenceRadius,
        'active_mosque': _activeMosque,
        'active_masjid_lat': _selectedLat,
        'active_masjid_lng': _selectedLng,
        'saved_mosques': _savedMosques,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Local Cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_silent_enabled', _isAutoSilentEnabled);
      await prefs.setDouble('silent_radius', _geofenceRadius);

      // IMMEDIATE LOCATION & DND CHECK
      if (_isAutoSilentEnabled) {
        Position currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );

        double distance = Geolocator.distanceBetween(
          currentPos.latitude,
          currentPos.longitude,
          _selectedLat!,
          _selectedLng!,
        );

        if (distance <= _geofenceRadius) {
          await DndService.enableDnd();
          _showSnackBar("Location saved! Phone set to SILENT (Inside Mosque Zone).", const Color(0xFF2E7D32));
        } else {
          await DndService.disableDnd();
          _showSnackBar("Location saved! Auto-silent active when you reach the mosque.", const Color(0xFF2E7D32));
        }

        // Start background service
        final service = FlutterBackgroundService();
        if (!await service.isRunning()) {
          await service.startService();
        }
      } else {
        await DndService.disableDnd();
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          service.invoke("stopService");
        }
        _showSnackBar("Settings saved. Auto-silent is disabled.", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("Failed to save settings: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Delete mosque from saved list
  Future<void> _deleteMosque(int index) async {
    setState(() {
      final removed = _savedMosques.removeAt(index);
      if (_activeMosque != null && _activeMosque!['id'] == removed['id']) {
        _activeMosque = _savedMosques.isNotEmpty ? _savedMosques.first : null;
        if (_activeMosque != null) {
          _selectedLat = (_activeMosque!['lat'] as num).toDouble();
          _selectedLng = (_activeMosque!['lng'] as num).toDouble();
          _nameController.text = _activeMosque!['name'] ?? '';
        } else {
          _selectedLat = null;
          _selectedLng = null;
          _nameController.text = '';
        }
      }
    });

    await _firestore.collection('masjid_settings').doc(_docId).update({
      'saved_mosques': _savedMosques,
      'active_mosque': _activeMosque,
      'active_masjid_lat': _selectedLat ?? 0.0,
      'active_masjid_lng': _selectedLng ?? 0.0,
    });

    _showSnackBar("Mosque removed from saved list.", Colors.grey.shade800);
  }

  /// Select a saved mosque as current active
  void _selectSavedMosque(Map<String, dynamic> mosque) {
    setState(() {
      _activeMosque = mosque;
      _selectedLat = (mosque['lat'] as num).toDouble();
      _selectedLng = (mosque['lng'] as num).toDouble();
      _nameController.text = mosque['name'] ?? '';
    });
    _showSnackBar("Selected '${mosque['name']}' as active mosque.", const Color(0xFF2E7D32));
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bgColor,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA);
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final primaryGreen = const Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Auto-Silent Mosque Mode",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Options Card
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text(
                        "Search / Add Mosque on Map",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MasjidMapScreen()),
                        ).then((_) => _loadAllData());
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Currently Selected Active Mosque Card
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.mosque, color: primaryGreen, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Active Mosque Location",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: primaryTextColor),
                      decoration: InputDecoration(
                        labelText: 'Mosque Name',
                        labelStyle: TextStyle(color: secondaryTextColor),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryGreen, width: 2),
                        ),
                        prefixIcon: Icon(Icons.location_city, color: secondaryTextColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Toggle & Radius Settings Card
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Auto-Silent Mode',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Automatically silences phone inside mosque zone',
                                style: TextStyle(color: secondaryTextColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAutoSilentEnabled,
                          activeThumbColor: primaryGreen,
                          onChanged: (val) => setState(() => _isAutoSilentEnabled = val),
                        ),
                      ],
                    ),
                    if (_isAutoSilentEnabled) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Silent Zone Radius:',
                              style: TextStyle(fontSize: 14, color: primaryTextColor)),
                          Text(
                            '${_geofenceRadius.round()} meters',
                            style: TextStyle(
                                color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      Slider(
                        value: _geofenceRadius,
                        min: 50,
                        max: 500,
                        divisions: 9,
                        activeColor: primaryGreen,
                        inactiveColor: isDarkMode ? Colors.grey.shade800 : Colors.green.shade100,
                        onChanged: (val) => setState(() => _geofenceRadius = val),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Saved Mosques List Section
            if (_savedMosques.isNotEmpty) ...[
              Text(
                "Saved Mosque Locations",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _savedMosques.length,
                itemBuilder: (context, index) {
                  final item = _savedMosques[index];
                  final isSelected = _activeMosque != null && _activeMosque!['id'] == item['id'];

                  return Card(
                    color: isSelected ? primaryGreen.withValues(alpha: 0.15) : cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? primaryGreen : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: isSelected ? primaryGreen : secondaryTextColor,
                      ),
                      title: Text(
                        item['name'] ?? 'Mosque',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: primaryTextColor,
                        ),
                      ),
                      subtitle: Text(
                        "Lat: ${(item['lat'] as num).toStringAsFixed(3)}, Lng: ${(item['lng'] as num).toStringAsFixed(3)}",
                        style: TextStyle(color: secondaryTextColor, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteMosque(index),
                      ),
                      onTap: () => _selectSavedMosque(item),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Save Settings Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: _isLoading ? null : _saveAllSettings,
                child: const Text(
                  'Save & Activate Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}