import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/dnd_service.dart';
import 'masjid_silence_screen.dart';

// BACKGROUND SERVICE & AUTOMATIC DND LOGIC
Future<void> initializeBackgroundService() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'masjid_silent_channel',
      initialNotificationTitle: 'Masjid Auto-Silent Active',
      initialNotificationContent: 'Monitoring mosque geofence location...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!await service.isForegroundService()) {
        timer.cancel();
        return;
      }
    }

    try {
      final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'user_masjid_config';

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('masjid_settings')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool isEnabled = data['is_auto_silent_enabled'] ?? false;
        double targetLat = (data['active_masjid_lat'] as num?)?.toDouble() ?? 0.0;
        double targetLng = (data['active_masjid_lng'] as num?)?.toDouble() ?? 0.0;
        double radius = (data['geofence_radius'] as num?)?.toDouble() ?? 100.0;

        if (isEnabled && targetLat != 0.0 && targetLng != 0.0) {
          Position currentPos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );

          double distanceInMeters = Geolocator.distanceBetween(
            currentPos.latitude,
            currentPos.longitude,
            targetLat,
            targetLng,
          );

          if (distanceInMeters <= radius) {
            await DndService.enableDnd();
            debugPrint("Inside Geofence Zone: DND Enabled automatically");
          } else {
            await DndService.disableDnd();
            debugPrint("Outside Geofence Zone: DND Disabled automatically");
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking location in background: $e");
    }
  });
}

// MAP SCREEN UI
class MasjidMapScreen extends StatefulWidget {
  const MasjidMapScreen({super.key});

  @override
  State<MasjidMapScreen> createState() => _MasjidMapScreenState();
}

class _MasjidMapScreenState extends State<MasjidMapScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedUserLocation;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  bool _isLoadingCurrentLocation = false;

  final TextEditingController _searchController = TextEditingController();

  static const LatLng _initialPosition = LatLng(33.6844, 73.0479);

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateLocationUI(LatLng point, String title) {
    setState(() {
      _selectedUserLocation = point;
      _markers.clear();
      _circles.clear();

      _markers.add(
        Marker(
          markerId: const MarkerId('selected_masjid'),
          position: point,
          infoWindow: InfoWindow(title: title),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      _circles.add(
        Circle(
          circleId: const CircleId('masjid_geofence'),
          center: point,
          radius: 100,
          fillColor: const Color(0x332E7D32),
          strokeColor: const Color(0xFF2E7D32),
          strokeWidth: 2,
        ),
      );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(point, 16.5),
    );
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (await Permission.accessNotificationPolicy.isDenied) {
      await Permission.accessNotificationPolicy.request();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    return true;
  }

  Future<void> _getCurrentLocation() async {
    bool hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permission is required.")),
      );
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please turn on GPS/Location services.")),
      );
      await Geolocator.openLocationSettings();
      return;
    }

    setState(() {
      _isLoadingCurrentLocation = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      String placeName = "Current Location";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          String name = place.name ?? '';
          String locality = place.locality ?? place.subLocality ?? '';
          placeName = "$name, $locality".trim();
          if (placeName.startsWith(',')) placeName = placeName.substring(1).trim();
        }
      } catch (_) {
        placeName = "Current Location (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})";
      }

      if (!mounted) return;

      _searchController.text = placeName;
      _updateLocationUI(currentLatLng, placeName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
      }
    }
  }

  void _searchMasjidByName() async {
    final String searchAddress = _searchController.text.trim();
    await _checkAndRequestPermissions();

    if (!mounted) return;

    if (searchAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a mosque name or address.")),
      );
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(searchAddress);
      if (locations.isNotEmpty) {
        final Location targetLoc = locations.first;
        final LatLng foundPoint = LatLng(targetLoc.latitude, targetLoc.longitude);
        _updateLocationUI(foundPoint, searchAddress);
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mosque location not found. Try tapping directly on the map.")),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Select Mosque Location",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 14.0,
            ),
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (LatLng tappedPoint) async {
              await _checkAndRequestPermissions();
              if (!mounted) return;

              _updateLocationUI(tappedPoint, "Selected Location");

              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  tappedPoint.latitude,
                  tappedPoint.longitude,
                );
                if (placemarks.isNotEmpty && mounted) {
                  setState(() {
                    _searchController.text =
                    "${placemarks.first.name ?? 'Mosque'}, ${placemarks.first.locality ?? ''}";
                  });
                }
              } catch (_) {
                if (mounted) {
                  setState(() {
                    _searchController.text =
                    "Selected Mosque (${tappedPoint.latitude.toStringAsFixed(3)}, ${tappedPoint.longitude.toStringAsFixed(3)})";
                  });
                }
              }
            },
          ),
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Card(
              color: cardBg,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _searchMasjidByName(),
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: "Search Mosque (e.g. Faisal Mosque)",
                          hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                          border: InputBorder.none,
                          icon: const Icon(Icons.mosque, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Color(0xFF2E7D32)),
                      onPressed: _searchMasjidByName,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 95,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: 'current_location_btn',
              onPressed: _isLoadingCurrentLocation ? null : _getCurrentLocation,
              backgroundColor: const Color(0xFF2E7D32),
              icon: _isLoadingCurrentLocation
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.my_location, color: Colors.white),
              label: const Text(
                "Use Current Location",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Positioned(
            bottom: 25,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () async {
                await _checkAndRequestPermissions();

                if (!mounted) return;

                if (_selectedUserLocation != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MasjidSettingsScreen(
                        initialLatitude: _selectedUserLocation!.latitude,
                        initialLongitude: _selectedUserLocation!.longitude,
                        initialMosqueName: _searchController.text.trim().isEmpty
                            ? "Selected Mosque"
                            : _searchController.text.trim(),
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please search or select a mosque on the map first.")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                backgroundColor: const Color(0xFF2E7D32),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                "Continue To Settings",
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}