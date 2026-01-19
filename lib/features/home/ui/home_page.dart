import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:insight/widgets/location_input_card.dart';

class HomePage extends StatefulWidget {
  final Future<void> Function()? onLogout;

  const HomePage({super.key, this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late GoogleMapController mapController;
  LatLng _currentPosition = const LatLng(24.8607, 67.0011);
  final Set<Marker> _markers = {};

  final TextEditingController fromCtrl = TextEditingController();
  final TextEditingController toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInternet();
      _checkLocationStatus();
    });

    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _determinePosition();
      }
    });

    Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled) {
        _determinePosition();
      }
    });
  }

  @override
  void dispose() {
    fromCtrl.dispose();
    toCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkInternet() async {
    var result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      _showError("Internet Error", "Please enable WiFi or mobile data.");
    }
  }

  Future<void> _checkLocationStatus() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _showError("Location Disabled", "Enable location to continue.");
    }
    await _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position pos = await Geolocator.getCurrentPosition();

    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId("currentLocation"),
          position: _currentPosition,
        ),
      );
    });

    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition, 15),
    );
  }

  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("InSight"),
        actions: [
          IconButton(
            tooltip: "Logout",
            onPressed: () async {
              if (widget.onLogout == null) return;
              await widget.onLogout!();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 12,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
            ),
          ),
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: LocationInputCard(
              fromController: fromCtrl,
              toController: toCtrl,
            ),
          ),
        ],
      ),
    );
  }
}
