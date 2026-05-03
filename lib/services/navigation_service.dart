import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_service.dart';
import 'package:firebase_core/firebase_core.dart';

/// Manages live GPS tracking, step-by-step advancement, TTS voice,
/// and Firebase IoT detection announcements (IoT has priority over nav TTS).
class NavigationService {
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<DatabaseEvent>? _iotSub;

  RouteResult? _route;
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  bool _voiceEnabled = true;
  bool _isSpeakingIot = false;

  // Persist between events so duplicate Firebase emissions can be ignored.
  String? _lastSpokenDetection;
  int? _lastSpokenTimestamp;
  bool _iotBaselineCaptured = false;

  static const double _stepAdvanceThreshold = 20.0;
  static const double _announceAheadMeters = 40.0;
  static const double _arrivalThreshold = 15.0;

  final DatabaseReference _iotRef = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://insight-64965-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref('iot/device_001');

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

  void Function(int stepIndex)? onStepAdvanced;
  void Function(LatLng position)? onPositionUpdate;
  void Function()? onArrived;
  void Function(String detection)? onIotDetection;

  Future<void> initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    print('✅ TTS initialized');

    _tts.setCompletionHandler(() {
      print('✅ TTS finished speaking');
      _isSpeakingIot = false;
    });
  }

  void toggleVoice() {
    _voiceEnabled = !_voiceEnabled;
    if (!_voiceEnabled) {
      _tts.stop();
      _isSpeakingIot = false;
    }
  }

  Future<void> startNavigation(RouteResult route) async {
    _route = route;
    _currentStepIndex = 0;
    _isNavigating = true;
    _isSpeakingIot = false;
    _lastSpokenDetection = null; // reset on every new navigation session
    _lastSpokenTimestamp = null;
    _iotBaselineCaptured = false;

    await initTts();

    if (_voiceEnabled && route.steps.isNotEmpty) {
      await _speak(route.steps[0].ttsAnnouncement, isIot: false);
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPosition);

    _startIotListener();
  }

  // ─── Firebase IoT Listener ─────────────────────────────────────────────────

  void _startIotListener() {
    _iotSub?.cancel();

    _iotSub = _iotRef.onValue.listen(
      (DatabaseEvent event) {
        print('🔥 RAW IoT event: ${event.snapshot.value}');
        print('🔥 isNavigating: $_isNavigating');

        if (!_isNavigating) return;

        final value = event.snapshot.value;
        if (!_iotBaselineCaptured) {
          _iotBaselineCaptured = true;

          if (value is Map) {
            final baselineData = Map<Object?, Object?>.from(value);
            _lastSpokenDetection =
                (baselineData['latest_detection'] ?? '').toString().trim();
            _lastSpokenTimestamp = int.tryParse(
              (baselineData['timestamp'] ?? '').toString(),
            );
            print(
              '🔥 Baseline captured on start: "$_lastSpokenDetection" @ $_lastSpokenTimestamp',
            );
          } else {
            print('🔥 Baseline captured on start: non-map payload');
          }
          return;
        }

        if (value is! Map) {
          print('🔥 Skipped: unexpected IoT payload shape');
          return;
        }

        final data = Map<Object?, Object?>.from(value);
        final detectionRaw = data['latest_detection'];
        final timestampRaw = data['timestamp'];

        final detection = (detectionRaw ?? '').toString().trim();
        final timestamp = int.tryParse((timestampRaw ?? '').toString());
        print('🔥 detection string: "$detection"');
        print('🔥 detection timestamp: $timestamp');

        // Skip empty or "no detection" strings
        if (detection.isEmpty ||
            detection.toLowerCase() == 'no detection' ||
            detection.toLowerCase() == 'no_detection') {
          print('🔥 Skipped: no detection string');
          return;
        }

        // Skip if duplicate payload (same detection + same timestamp).
        if (detection == _lastSpokenDetection &&
            timestamp == _lastSpokenTimestamp) {
          print(
            '🔥 Skipped: same detection+timestamp "$_lastSpokenDetection" @ $_lastSpokenTimestamp',
          );
          return;
        }

        _lastSpokenDetection = detection;
        _lastSpokenTimestamp = timestamp;
        print('🔥 Speaking IoT detection: "$detection"');

        onIotDetection?.call(detection);
        _speakIot(detection);
      },
      onError: (error) {
        print('❌ IoT listener error: $error');
      },
    );

    print('✅ IoT listener started');
  }

  void _stopIotListener() {
    _iotSub?.cancel();
    _iotSub = null;
  }

  // ─── TTS Priority Logic ────────────────────────────────────────────────────

  Future<void> _speakIot(String text) async {
    if (!_voiceEnabled) return;
    await _tts.stop();
    _isSpeakingIot = true;
    await _tts.speak(text);
  }

  Future<void> _speak(String text, {bool isIot = false}) async {
    if (!_voiceEnabled) return;
    if (_isSpeakingIot && !isIot) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  // ─── GPS Position Handling ─────────────────────────────────────────────────

  void _onPosition(Position pos) {
    if (!_isNavigating || _route == null) return;

    final current = LatLng(pos.latitude, pos.longitude);
    onPositionUpdate?.call(current);

    final steps = _route!.steps;
    if (_currentStepIndex >= steps.length) return;

    final step = steps[_currentStepIndex];
    final distToStepEnd = _distanceMeters(current, step.endLocation);

    final dest = steps.last.endLocation;
    if (_distanceMeters(current, dest) < _arrivalThreshold) {
      _arrive();
      return;
    }

    if (distToStepEnd < _stepAdvanceThreshold) {
      _advanceStep();
      return;
    }

    if (distToStepEnd < _announceAheadMeters &&
        _currentStepIndex + 1 < steps.length) {
      final next = steps[_currentStepIndex + 1];
      if (_voiceEnabled && !_isSpeakingIot) {
        _speak('In ${step.distance}, ${next.ttsAnnouncement}');
      }
    }
  }

  void _advanceStep() {
    if (_route == null) return;
    _currentStepIndex++;
    onStepAdvanced?.call(_currentStepIndex);

    if (_currentStepIndex < _route!.steps.length) {
      final step = _route!.steps[_currentStepIndex];
      if (_voiceEnabled && !_isSpeakingIot) {
        _speak(step.ttsAnnouncement);
      }
    }
  }

  void _arrive() {
    if (_voiceEnabled) _speak('You have arrived at your destination.');
    stopNavigation();
    onArrived?.call();
  }

  void stopNavigation() {
    _isNavigating = false;
    _isSpeakingIot = false;
    _lastSpokenDetection = null; // ✅ reset so next session starts fresh
    _lastSpokenTimestamp = null;
    _iotBaselineCaptured = false;
    _positionSub?.cancel();
    _positionSub = null;
    _stopIotListener();
    _tts.stop();
  }

  Future<void> speakStep(RouteStep step) => _speak(step.ttsAnnouncement);

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
