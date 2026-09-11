import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class QiblaFinderScreen extends StatefulWidget {
  const QiblaFinderScreen({Key? key}) : super(key: key);

  @override
  State<QiblaFinderScreen> createState() => _QiblaFinderScreenState();
}

class _QiblaFinderScreenState extends State<QiblaFinderScreen> {
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  bool _hasSensor = true;
  String _statusMessage = 'Initializing Qibla Finder...';

  double? _qiblaAngle; // Makkah direction from True North
  double _deviceHeading = 0.0; // Current device azimuth in degrees
  bool _hasVibrated = false;

  Position? _currentPosition;

  List<double>? _accelerometerValues;
  List<double>? _magnetometerValues;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  static const double _makkahLat = 21.422487;
  static const double _makkahLng = 39.826206;

  @override
  void initState() {
    super.initState();
    _initializeQiblaFinder();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeQiblaFinder() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking location permissions...';
    });

    bool permissionGranted = await _checkAndRequestLocationPermission();
    if (!permissionGranted) {
      setState(() {
        _isLoading = false;
        _hasLocationPermission = false;
        _statusMessage = 'Location permission is required for Qibla direction.';
      });
      return;
    }

    setState(() {
      _hasLocationPermission = true;
      _statusMessage = 'Fetching location...';
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
      _calculateQiblaDirection(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Unable to fetch location coordinates.';
      });
      return;
    }

    _startSensorListeners();
  }

  Future<bool> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return false;
    }

    return true;
  }

  void _calculateQiblaDirection(double userLat, double userLng) {
    double userLatRad = _toRadians(userLat);
    double userLngRad = _toRadians(userLng);
    double makkahLatRad = _toRadians(_makkahLat);
    double makkahLngRad = _toRadians(_makkahLng);

    double deltaLng = makkahLngRad - userLngRad;

    double y = math.sin(deltaLng);
    double x = math.cos(userLatRad) * math.tan(makkahLatRad) -
        math.sin(userLatRad) * math.cos(deltaLng);

    double qiblaRad = math.atan2(y, x);
    double qiblaDeg = _toDegrees(qiblaRad);

    qiblaDeg = (qiblaDeg + 360) % 360;

    setState(() {
      _qiblaAngle = qiblaDeg;
    });
  }

  void _startSensorListeners() {
    _accelSub = accelerometerEvents.listen(
          (AccelerometerEvent event) {
        _accelerometerValues = [event.x, event.y, event.z];
        _updateHeading();
      },
      onError: (_) => _handleSensorError(),
    );

    _magSub = magnetometerEvents.listen(
          (MagnetometerEvent event) {
        _magnetometerValues = [event.x, event.y, event.z];
        _updateHeading();
      },
      onError: (_) => _handleSensorError(),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (_magnetometerValues == null && mounted) {
        setState(() {
          _hasSensor = false;
          _isLoading = false;
          _statusMessage = 'Magnetometer sensor not detected on this phone.';
        });
      }
    });
  }

  void _handleSensorError() {
    if (!mounted) return;
    setState(() {
      _hasSensor = false;
      _isLoading = false;
      _statusMessage = 'Hardware compass sensor not responding.';
    });
  }

  void _updateHeading() {
    if (_accelerometerValues == null || _magnetometerValues == null) return;

    final ax = _accelerometerValues![0];
    final ay = _accelerometerValues![1];
    final az = _accelerometerValues![2];

    final mx = _magnetometerValues![0];
    final my = _magnetometerValues![1];
    final mz = _magnetometerValues![2];

    double normAcc = math.sqrt(ax * ax + ay * ay + az * az);
    if (normAcc == 0) return;

    double pitch = math.asin(-ay / normAcc);
    double roll = math.atan2(ax, az);

    double mxComp = mx * math.cos(roll) + mz * math.sin(roll);
    double myComp = mx * math.sin(pitch) * math.sin(roll) +
        my * math.cos(pitch) -
        mz * math.sin(pitch) * math.cos(roll);

    double headingRad = math.atan2(-mxComp, myComp);
    double headingDeg = _toDegrees(headingRad);
    headingDeg = (headingDeg + 360) % 360;

    if (!mounted) return;

    double smoothedHeading =
        _deviceHeading + (headingDeg - _deviceHeading) * 0.2;

    if (_qiblaAngle != null) {
      double diff = (smoothedHeading - _qiblaAngle!).abs();
      if (diff > 180) diff = 360 - diff;

      if (diff <= 3.0) {
        if (!_hasVibrated) {
          HapticFeedback.vibrate();
          _hasVibrated = true;
        }
      } else {
        _hasVibrated = false;
      }
    }

    setState(() {
      _deviceHeading = smoothedHeading;
      _isLoading = false;
      _hasSensor = true;
    });
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
  double _toDegrees(double radians) => radians * (180.0 / math.pi);

  Map<String, dynamic> _getGuidanceDetails() {
    if (_qiblaAngle == null) {
      return {
        'message': 'Calculating...',
        'color': Colors.grey,
        'icon': Icons.hourglass_bottom
      };
    }

    double diff = (_qiblaAngle! - _deviceHeading + 360) % 360;

    if (diff <= 4 || diff >= 356) {
      return {
        'message': 'You are facing the Qibla!',
        'color': Colors.lightGreenAccent,
        'icon': Icons.check_circle,
      };
    } else if (diff < 180) {
      return {
        'message': 'Rotate Right ↱',
        'color': Colors.amberAccent,
        'icon': Icons.rotate_right,
      };
    } else {
      return {
        'message': 'Rotate Left ↰',
        'color': Colors.amberAccent,
        'icon': Icons.rotate_left,
      };
    }
  }

  /// Opens Google Map Fallback screen for non-compass devices
  void _openQiblaMapFallback() {
    if (_currentPosition == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QiblaMapFallbackScreen(
          userLat: _currentPosition!.latitude,
          userLng: _currentPosition!.longitude,
          qiblaAngle: _qiblaAngle ?? 256.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF032219),
      appBar: AppBar(
        title: const Text('Qibla Finder',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.lightGreenAccent),
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (!_hasLocationPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(_statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeQiblaFinder,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }

    // -----------------------------------------------------------------
    // FALLBACK UI FOR PHONES WITHOUT MAGNETOMETER SENSOR
    // -----------------------------------------------------------------
    if (!_hasSensor) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_off, size: 64, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              const Text(
                'Compass Sensor Unavailable',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your device does not support a live compass sensor.\n\nCalculated Qibla Angle: ${_qiblaAngle?.toStringAsFixed(1)}° (Clockwise from True North)',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text(
                  'View Qibla Direction on Map',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                onPressed: _openQiblaMapFallback,
              ),
            ],
          ),
        ),
      );
    }

    final double qiblaAngle = _qiblaAngle ?? 0.0;
    final double compassDialRadians = -_deviceHeading * (math.pi / 180.0);
    final double kaabaOnDialRadians =
        (qiblaAngle - _deviceHeading) * (math.pi / 180.0);

    final guidance = _getGuidanceDetails();

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            children: [
              Text(
                'Qibla Direction: ${qiblaAngle.toStringAsFixed(1)}°',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 24),

              // Live Guidance Message
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: (guidance['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border:
                  Border.all(color: guidance['color'] as Color, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(guidance['icon'] as IconData,
                        color: guidance['color'] as Color, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      guidance['message'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: guidance['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Compass Display
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Rotating Compass Dial
                    Transform.rotate(
                      angle: compassDialRadians,
                      child: Image.asset('assets/images/compass.jpg', width: 280),
                    ),

                    // 2. Kaaba Icon placed exact on Dial at Qibla Position
                    Transform.rotate(
                      angle: kaabaOnDialRadians,
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Icon(
                              Icons.mosque,
                              size: 32,
                              color: guidance['color'] as Color,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. Static Center Pointer Needle
                    Image.asset('assets/images/needle.jpg', width: 120),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Keep your phone flat for best results. When the needle points to the mosque icon, you are facing the Qibla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAP FALLBACK SCREEN FOR NON-MAGNETOMETER PHONES
// ============================================================================
class QiblaMapFallbackScreen extends StatelessWidget {
  final double userLat;
  final double userLng;
  final double qiblaAngle;

  const QiblaMapFallbackScreen({
    Key? key,
    required this.userLat,
    required this.userLng,
    required this.qiblaAngle,
  }) : super(key: key);

  static const double _makkahLat = 21.422487;
  static const double _makkahLng = 39.826206;

  @override
  Widget build(BuildContext context) {
    final LatLng userLocation = LatLng(userLat, userLng);
    final LatLng makkahLocation = const LatLng(_makkahLat, _makkahLng);

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('user_location'),
        position: userLocation,
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      Marker(
        markerId: const MarkerId('makkah_location'),
        position: makkahLocation,
        infoWindow: const InfoWindow(title: 'Khana Kaaba (Makkah)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
    };

    final Set<Polyline> polylines = {
      Polyline(
        polylineId: const PolylineId('qibla_line'),
        points: [userLocation, makkahLocation],
        color: const Color(0xFF2E7D32),
        width: 4,
        geodesic: true,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla Map View'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userLocation,
              zoom: 16.0,
            ),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Follow the green line towards Khana Kaaba.\nQibla Direction: ${qiblaAngle.toStringAsFixed(1)}° from North',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}