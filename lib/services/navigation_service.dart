import 'dart:async';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_service.dart';

/// Manages live GPS tracking, step-by-step advancement, and TTS voice.
class NavigationService {
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Position>? _positionSub;

  RouteResult? _route;
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  bool _voiceEnabled = true;

  // How close (meters) the user must be to a step's end to advance
  static const double _stepAdvanceThreshold = 20.0;
  // Announce next step when within this many meters
  static const double _announceAheadMeters = 40.0;
  // Announce "arriving" when within this many meters of destination
  static const double _arrivalThreshold = 15.0;

  bool get isNavigating => _isNavigating;
  bool get voiceEnabled => _voiceEnabled;
  int get currentStepIndex => _currentStepIndex;
  RouteStep? get currentStep =>
      _route != null && _currentStepIndex < _route!.steps.length
          ? _route!.steps[_currentStepIndex]
          : null;
  RouteStep? get nextStep =>
      _route != null && _currentStepIndex + 1 < _route!.steps.length
          ? _route!.steps[_currentStepIndex + 1]
          : null;

  // Callbacks for the UI to react
  void Function(int stepIndex)? onStepAdvanced;
  void Function(LatLng position)? onPositionUpdate;
  void Function()? onArrived;

  Future<void> initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void toggleVoice() {
    _voiceEnabled = !_voiceEnabled;
    if (!_voiceEnabled) _tts.stop();
  }

  Future<void> startNavigation(RouteResult route) async {
    _route = route;
    _currentStepIndex = 0;
    _isNavigating = true;

    await initTts();

    // Announce first step immediately
    if (_voiceEnabled && route.steps.isNotEmpty) {
      await _speak(route.steps[0].ttsAnnouncement);
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // fire every 5 m of movement
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position pos) {
    if (!_isNavigating || _route == null) return;

    final current = LatLng(pos.latitude, pos.longitude);
    onPositionUpdate?.call(current);

    final steps = _route!.steps;
    if (_currentStepIndex >= steps.length) return;

    final step = steps[_currentStepIndex];
    final distToStepEnd = _distanceMeters(current, step.endLocation);

    // ── Check arrival at final destination ───────────────────────────────────
    final dest = steps.last.endLocation;
    if (_distanceMeters(current, dest) < _arrivalThreshold) {
      _arrive();
      return;
    }

    // ── Advance step when close enough to step end ───────────────────────────
    if (distToStepEnd < _stepAdvanceThreshold) {
      _advanceStep();
      return;
    }

    // ── Pre-announce next step when approaching step end ─────────────────────
    if (distToStepEnd < _announceAheadMeters &&
        _currentStepIndex + 1 < steps.length) {
      final next = steps[_currentStepIndex + 1];
      if (_voiceEnabled) _speak('In ${step.distance}, ${next.ttsAnnouncement}');
    }
  }

  void _advanceStep() {
    if (_route == null) return;
    _currentStepIndex++;
    onStepAdvanced?.call(_currentStepIndex);

    if (_currentStepIndex < _route!.steps.length) {
      final step = _route!.steps[_currentStepIndex];
      if (_voiceEnabled) _speak(step.ttsAnnouncement);
    }
  }

  void _arrive() {
    if (_voiceEnabled) _speak('You have arrived at your destination.');
    stopNavigation();
    onArrived?.call();
  }

  void stopNavigation() {
    _isNavigating = false;
    _positionSub?.cancel();
    _positionSub = null;
    _tts.stop();
  }

  /// Re-speak any step on demand (called when user taps a step in the list)
  Future<void> speakStep(RouteStep step) => _speak(step.ttsAnnouncement);

  Future<void> _speak(String text) async {
    if (!_voiceEnabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Haversine distance in meters between two LatLng points
  static double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final x =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  void dispose() {
    stopNavigation();
    _tts.stop();
  }
}
