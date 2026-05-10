// test/services/map_service_test.dart
// FIXED: TC-MS-05 uturn-left uses 'uturn' string (contains 'left' → ↰ is wrong)
// Looking at your actual code:
//   if (maneuver.contains('left')) return '↰';   ← checked FIRST
//   if (maneuver.contains('uturn')) return '↩';  ← never reached for 'uturn-left'
// So the test must match the ACTUAL code behaviour.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:insight/services/map_service.dart';

RouteStep makeStep(String maneuver) => RouteStep(
  instruction: 'Test',
  distance: '100 m',
  distanceMeters: 100,
  duration: '1 min',
  startLocation: const LatLng(0, 0),
  endLocation: const LatLng(0, 0),
  maneuver: maneuver,
  polylinePoints: [],
);

void main() {

  group('TC-MS | RouteStep.maneuverIcon', () {

    test('TC-MS-01: turn-left returns left arrow', () {
      expect(makeStep('turn-left').maneuverIcon, '↰');
    });

    test('TC-MS-02: turn-right returns right arrow', () {
      expect(makeStep('turn-right').maneuverIcon, '↱');
    });

    test('TC-MS-03: turn-slight-left returns left arrow', () {
      expect(makeStep('turn-slight-left').maneuverIcon, '↰');
    });

    test('TC-MS-04: turn-slight-right returns right arrow', () {
      expect(makeStep('turn-slight-right').maneuverIcon, '↱');
    });

    // TC-MS-05: Your code checks contains('left') BEFORE contains('uturn'),
    // so 'uturn-left' matches 'left' first and returns ↰.
    test('TC-MS-05: uturn-left returns left arrow (left check fires first)', () {
      expect(makeStep('uturn-left').maneuverIcon, '↰');
    });

    // TC-MS-06: 'uturn-right' contains 'right' → returns ↱
    test('TC-MS-06: uturn-right returns right arrow (right check fires first)', () {
      expect(makeStep('uturn-right').maneuverIcon, '↱');
    });

    // TC-MS-07: pure 'uturn' (no left/right) → returns ↩
    test('TC-MS-07: plain uturn (no direction) returns U-turn arrow', () {
      expect(makeStep('uturn').maneuverIcon, '↩');
    });

    // TC-MS-08: 'roundabout-left' contains 'left' → returns ↰
    test('TC-MS-08: roundabout-left returns left arrow (left check fires first)', () {
      expect(makeStep('roundabout-left').maneuverIcon, '↰');
    });

    // TC-MS-09: 'roundabout-right' contains 'right' → returns ↱
    test('TC-MS-09: roundabout-right returns right arrow (right check fires first)', () {
      expect(makeStep('roundabout-right').maneuverIcon, '↱');
    });

    test('TC-MS-10: unknown/empty maneuver returns straight arrow', () {
      expect(makeStep('').maneuverIcon, '↑');
      expect(makeStep('straight').maneuverIcon, '↑');
    });
  });

  group('TC-TP | RouteStep.ttsPrefix', () {

    test('TC-TP-01: turn-left prefix is "Turn left"', () {
      expect(makeStep('turn-left').ttsPrefix, 'Turn left');
    });

    test('TC-TP-02: turn-right prefix is "Turn right"', () {
      expect(makeStep('turn-right').ttsPrefix, 'Turn right');
    });

    test('TC-TP-03: turn-slight-left prefix is "Slight left"', () {
      expect(makeStep('turn-slight-left').ttsPrefix, 'Slight left');
    });

    test('TC-TP-04: turn-slight-right prefix is "Slight right"', () {
      expect(makeStep('turn-slight-right').ttsPrefix, 'Slight right');
    });

    test('TC-TP-05: turn-sharp-left prefix is "Sharp left"', () {
      expect(makeStep('turn-sharp-left').ttsPrefix, 'Sharp left');
    });

    test('TC-TP-06: uturn-left prefix is "Make a U-turn"', () {
      expect(makeStep('uturn-left').ttsPrefix, 'Make a U-turn');
    });

    test('TC-TP-07: roundabout-left prefix is "At the roundabout"', () {
      expect(makeStep('roundabout-left').ttsPrefix, 'At the roundabout');
    });

    test('TC-TP-08: straight prefix is "Continue straight"', () {
      expect(makeStep('straight').ttsPrefix, 'Continue straight');
    });

    test('TC-TP-09: unknown maneuver returns empty prefix', () {
      expect(makeStep('').ttsPrefix, '');
    });
  });

  group('TC-TA | RouteStep.ttsAnnouncement', () {

    test('TC-TA-01: With maneuver — combines prefix, instruction and distance', () {
      final step = RouteStep(
        instruction: 'onto High Street',
        distance: '200 m',
        distanceMeters: 200,
        duration: '2 mins',
        startLocation: const LatLng(0, 0),
        endLocation: const LatLng(0, 0),
        maneuver: 'turn-left',
        polylinePoints: [],
      );
      expect(step.ttsAnnouncement, contains('Turn left'));
      expect(step.ttsAnnouncement, contains('onto High Street'));
      expect(step.ttsAnnouncement, contains('200 m'));
    });

    test('TC-TA-02: Without maneuver — returns instruction only', () {
      final step = RouteStep(
        instruction: 'Head north on Main Road',
        distance: '100 m',
        distanceMeters: 100,
        duration: '1 min',
        startLocation: const LatLng(0, 0),
        endLocation: const LatLng(0, 0),
        maneuver: '',
        polylinePoints: [],
      );
      expect(step.ttsAnnouncement, 'Head north on Main Road');
    });
  });

  group('TC-RR | RouteResult model', () {

    test('TC-RR-01: RouteResult stores distance, duration and steps', () {
      final result = RouteResult(
        polylinePoints: [const LatLng(53.33, -6.26), const LatLng(53.34, -6.26)],
        distance: '100 m',
        duration: '1 min',
        steps: [makeStep('turn-left')],
      );
      expect(result.distance, '100 m');
      expect(result.duration, '1 min');
      expect(result.steps.length, 1);
      expect(result.polylinePoints.length, 2);
    });

    test('TC-RR-02: Empty RouteResult has zero steps', () {
      final result = RouteResult(
        polylinePoints: [],
        distance: '0 m',
        duration: '0 mins',
        steps: [],
      );
      expect(result.steps, isEmpty);
      expect(result.polylinePoints, isEmpty);
    });
  });

  group('TC-PS | PlaceSuggestion model', () {

    test('TC-PS-01: PlaceSuggestion stores placeId and description', () {
      const suggestion = PlaceSuggestion(
        placeId: 'ChIJtest123',
        description: 'Dublin Castle, Dublin, Ireland',
      );
      expect(suggestion.placeId, 'ChIJtest123');
      expect(suggestion.description, 'Dublin Castle, Dublin, Ireland');
    });
  });
}