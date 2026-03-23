import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '/services/map_service.dart';
import '/services/navigation_service.dart';
import '/widgets/location_input_card.dart';

class HomePage extends StatefulWidget {
  final Future<void> Function()? onLogout;
  const HomePage({super.key, this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late GoogleMapController _mapController;

  LatLng _currentPosition = const LatLng(24.8607, 67.0011);
  LatLng? _destinationLatLng;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  bool _isLoading = false;
  RouteResult? _routeResult;

  final NavigationService _nav = NavigationService();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInternet();
      _checkLocationStatus();
    });

    Connectivity().onConnectivityChanged.listen((r) {
      if (r != ConnectivityResult.none) _determinePosition();
    });

    Geolocator.getServiceStatusStream().listen((s) {
      if (s == ServiceStatus.enabled) _determinePosition();
    });

    // Wire up navigation callbacks
    _nav.onStepAdvanced = (index) {
      if (mounted) setState(() {});
    };
    _nav.onPositionUpdate = (pos) {
      if (mounted) {
        setState(() => _currentPosition = pos);
        if (_isNavigating) {
          _mapController.animateCamera(CameraUpdate.newLatLng(pos));
        }
      }
    };
    _nav.onArrived = () {
      if (mounted) {
        setState(() => _isNavigating = false);
        _showInfo('You arrived!', 'You have reached your destination.');
      }
    };
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _nav.dispose();
    super.dispose();
  }

  // ─── Location ──────────────────────────────────────────────────────────────

  Future<void> _checkInternet() async {
    final r = await Connectivity().checkConnectivity();
    if (r == ConnectivityResult.none) {
      _showError('No Internet', 'Please enable WiFi or mobile data.');
    }
  }

  Future<void> _checkLocationStatus() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled)
      _showError('Location Disabled', 'Enable location to continue.');
    await _determinePosition();
  }

  Future<void> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return;
    }
    if (perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    final latlng = LatLng(pos.latitude, pos.longitude);

    setState(() {
      _currentPosition = latlng;
      _fromCtrl.text = 'My Location';
      _markers.removeWhere((m) => m.markerId.value == 'me');
      _markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: latlng,
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    });

    _mapController.animateCamera(CameraUpdate.newLatLngZoom(latlng, 16));
  }

  // ─── Route ─────────────────────────────────────────────────────────────────

  Future<void> _onSearch() async {
    if (_destinationLatLng == null) {
      _showError('No Destination', 'Please select a destination first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _polylines.clear();
      _routeResult = null;
    });

    final result = await MapService.getWalkingDirections(
      origin: _currentPosition,
      destination: _destinationLatLng!,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoading = false);
      _showError('Route Error', 'Could not find a walking route.');
      return;
    }

    setState(() {
      _isLoading = false;
      _routeResult = result;

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('walk'),
          color: Colors.blue.shade600,
          width: 6,
          points: result.polylinePoints,
          patterns: [PatternItem.dot, PatternItem.gap(12)], // dotted = walking
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );

      _markers.removeWhere((m) => m.markerId.value == 'dest');
      _markers.add(
        Marker(
          markerId: const MarkerId('dest'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _toCtrl.text),
        ),
      );
    });

    _fitRoute(result.polylinePoints);
  }

  void _startNavigation() {
    if (_routeResult == null) return;
    setState(() => _isNavigating = true);
    _nav.startNavigation(_routeResult!);
    // Zoom to user for navigation view
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition, 18),
    );
  }

  void _stopNavigation() {
    _nav.stopNavigation();
    setState(() {
      _isNavigating = false;
    });
    if (_routeResult != null) _fitRoute(_routeResult!.polylinePoints);
  }

  void _clearAll() {
    _stopNavigation();
    setState(() {
      _polylines.clear();
      _routeResult = null;
      _destinationLatLng = null;
      _toCtrl.clear();
      _markers.removeWhere((m) => m.markerId.value == 'dest');
    });
  }

  void _fitRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  // ─── Destination selected from autocomplete ────────────────────────────────

  Future<void> _onToSelected(PlaceSuggestion s) async {
    final latlng = await MapService.getPlaceLatLng(s.placeId);
    if (latlng != null && mounted) setState(() => _destinationLatLng = latlng);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  void _showError(String title, String msg) => showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
  );

  void _showInfo(String title, String msg) => showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
  );

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          _isNavigating
              ? null
              : AppBar(
                title: const Text('InSight'),
                actions: [
                  if (_routeResult != null)
                    IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: _clearAll,
                    ),
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      if (widget.onLogout != null) await widget.onLogout!();
                    },
                  ),
                ],
              ),
      body: Stack(
        children: [
          // ── Google Map ───────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (c) => _mapController = c,
              initialCameraPosition: CameraPosition(
                target: _currentPosition,
                zoom: 14,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: !_isNavigating,
              markers: _markers,
              polylines: _polylines,
              zoomControlsEnabled: false,
            ),
          ),

          // ── Search card (hidden during navigation) ───────────────────────
          if (!_isNavigating)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: LocationInputCard(
                fromController: _fromCtrl,
                toController: _toCtrl,
                userLocation: _currentPosition,
                onToSelected: _onToSelected,
                onSearch: _onSearch,
                isLoading: _isLoading,
              ),
            ),

          // ── "Start Navigation" pill (after route is shown) ───────────────
          if (_routeResult != null && !_isNavigating)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _StartNavigationBar(
                result: _routeResult!,
                onStart: _startNavigation,
              ),
            ),

          // ── Navigation banner (step instruction, voice toggle, stop) ─────
          if (_isNavigating)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _NavigationBanner(
                nav: _nav,
                onStop: _stopNavigation,
                onToggleVoice: () => setState(() => _nav.toggleVoice()),
              ),
            ),

          // ── Navigation step list (bottom sheet during nav) ───────────────
          if (_isNavigating && _routeResult != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StepListSheet(
                steps: _routeResult!.steps,
                currentIndex: _nav.currentStepIndex,
                onStepTap: (step) => _nav.speakStep(step),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Start Navigation Bar ─────────────────────────────────────────────────────

class _StartNavigationBar extends StatelessWidget {
  final RouteResult result;
  final VoidCallback onStart;

  const _StartNavigationBar({required this.result, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.directions_walk, color: Colors.green.shade600, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.duration,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${result.distance} · Walking',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Navigation Banner (top of screen during navigation) ─────────────────────

class _NavigationBanner extends StatelessWidget {
  final NavigationService nav;
  final VoidCallback onStop;
  final VoidCallback onToggleVoice;

  const _NavigationBanner({
    required this.nav,
    required this.onStop,
    required this.onToggleVoice,
  });

  @override
  Widget build(BuildContext context) {
    final step = nav.currentStep;
    return Container(
      color: Colors.green.shade700,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Maneuver icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              step?.maneuverIcon ?? '↑',
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(width: 12),

          // Instruction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step?.instruction ?? 'Follow the route',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (step != null)
                  Text(
                    step.distance,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Voice toggle
          IconButton(
            icon: Icon(
              nav.voiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
            ),
            onPressed: onToggleVoice,
            tooltip: nav.voiceEnabled ? 'Mute voice' : 'Unmute voice',
          ),

          // Stop navigation
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onStop,
            tooltip: 'Stop navigation',
          ),
        ],
      ),
    );
  }
}

// ─── Step List Sheet (collapsible, shows all steps) ───────────────────────────

class _StepListSheet extends StatelessWidget {
  final List<RouteStep> steps;
  final int currentIndex;
  final void Function(RouteStep step) onStepTap;

  const _StepListSheet({
    required this.steps,
    required this.currentIndex,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: steps.length,
              itemBuilder: (_, i) {
                final step = steps[i];
                final isCurrent = i == currentIndex;
                final isDone = i < currentIndex;
                return ListTile(
                  dense: true,
                  onTap: () => onStepTap(step),
                  leading: Text(
                    step.maneuverIcon,
                    style: TextStyle(
                      fontSize: 18,
                      color:
                          isCurrent
                              ? Colors.green.shade700
                              : isDone
                              ? Colors.grey.shade400
                              : Colors.black,
                    ),
                  ),
                  title: Text(
                    step.instruction,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                      color: isDone ? Colors.grey.shade400 : Colors.black87,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.distance,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.volume_up_outlined,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
