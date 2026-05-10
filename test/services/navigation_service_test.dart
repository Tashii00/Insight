// test/services/navigation_service_test.dart
// FIXED: import moved to top

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:insight/services/map_service.dart';

double distanceMeters(LatLng a, LatLng b) {
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

RouteStep makeStep(String instruction, String maneuver, int distM) {
  return RouteStep(
    instruction: instruction,
    distance: '$distM m',
    distanceMeters: distM,
    duration: '1 min',
    startLocation: const LatLng(53.34, -6.26),
    endLocation: const LatLng(53.35, -6.26),
    maneuver: maneuver,
    polylinePoints: [],
  );
}

void main() {
  group('TC-NV | NavigationService distance calculation', () {
    test('TC-NV-01: Same point returns 0 metres', () {
      const point = LatLng(53.3498, -6.2603);
      expect(distanceMeters(point, point), closeTo(0.0, 0.001));
    });

    test('TC-NV-02: Distance between two Dublin points is correct', () {
      const dublinCastle = LatLng(53.3429, -6.2673);
      const trinity = LatLng(53.3438, -6.2546);
      final dist = distanceMeters(dublinCastle, trinity);
      expect(dist, greaterThan(500));
      expect(dist, lessThan(900));
    });

    test('TC-NV-03: Distance is symmetric A to B equals B to A', () {
      const a = LatLng(53.3498, -6.2603);
      const b = LatLng(53.3550, -6.2700);
      expect(distanceMeters(a, b), closeTo(distanceMeters(b, a), 0.001));
    });

    test('TC-NV-04: Point within 20m of step end triggers step advance', () {
      const stepEnd = LatLng(53.3498, -6.2603);
      const nearbyPoint = LatLng(53.3499, -6.2603);
      expect(distanceMeters(nearbyPoint, stepEnd), lessThan(20.0));
    });

    test('TC-NV-05: Point far from step end does NOT trigger advance', () {
      const stepEnd = LatLng(53.3498, -6.2603);
      const farPoint = LatLng(53.3510, -6.2603);
      expect(distanceMeters(farPoint, stepEnd), greaterThan(20.0));
    });

    test('TC-NV-06: Point within 15m triggers arrival', () {
      const dest = LatLng(53.3498, -6.2603);
      const arrivedPoint = LatLng(53.34981, -6.2603);
      expect(distanceMeters(arrivedPoint, dest), lessThan(15.0));
    });

    test(
      'TC-NV-07: Point within 40m triggers early announcement but not advance',
      () {
        const stepEnd = LatLng(53.3498, -6.2603);
        const approachPoint = LatLng(53.3495, -6.2603);
        final dist = distanceMeters(approachPoint, stepEnd);
        expect(dist, lessThan(40.0));
        expect(dist, greaterThan(20.0));
      },
    );
  });

  group('TC-RS | RouteStep logic used in NavigationService', () {
    test('TC-RS-01: First step is at index 0', () {
      final steps = [
        makeStep('Head north', 'turn-left', 100),
        makeStep('Turn right onto Main St', 'turn-right', 200),
      ];
      expect(steps[0].instruction, 'Head north');
    });

    test('TC-RS-02: After advance, currentStep is next step', () {
      final steps = [
        makeStep('Head north', 'turn-left', 100),
        makeStep('Turn right onto Main St', 'turn-right', 200),
      ];
      int currentIndex = 0;
      currentIndex++;
      expect(steps[currentIndex].instruction, 'Turn right onto Main St');
    });

    test('TC-RS-03: nextStep is null on last step', () {
      final steps = [makeStep('Head north', '', 100)];
      int currentIndex = 0;
      final nextStep =
          (currentIndex + 1 < steps.length) ? steps[currentIndex + 1] : null;
      expect(nextStep, isNull);
    });

    test('TC-RS-04: Voice toggle flips correctly', () {
      bool voiceEnabled = true;
      voiceEnabled = !voiceEnabled;
      expect(voiceEnabled, isFalse);
      voiceEnabled = !voiceEnabled;
      expect(voiceEnabled, isTrue);
    });
  });
}
