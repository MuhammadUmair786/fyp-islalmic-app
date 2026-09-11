import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Default location (Islamabad)
  static const LatLng _initialPosition = LatLng(33.6844, 73.0479);

  // Markers (Pins) store karne ke liye set
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Screen khulne par default marker lagane ke liye
    _markers.add(
      const Marker(
        markerId: MarkerId('default_masjid_pin'),
        position: _initialPosition,
        infoWindow: InfoWindow(
          title: 'Masjid Location',
          snippet: 'Auto-Silencer Target Area',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masjid Map View'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: const CameraPosition(
          target: _initialPosition,
          zoom: 15.0,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onTap: (LatLng latLng) {
          setState(() {
            _markers.clear(); // Purana pin hatane ke liye
            _markers.add(
              Marker(
                markerId: const MarkerId('new_masjid_pin'),
                position: latLng,
                infoWindow: const InfoWindow(title: 'Selected Location'),
              ),
            );
          });
          debugPrint("Selected Location: ${latLng.latitude}, ${latLng.longitude}");
        },
      ),
    );
  }
}
