import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MapService {
  static const String _apiKey = 'AIzaSyDz9uPsUzv9X5svxgADBM1VVV0JTfg-euE';
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';

  // ─── Places Autocomplete (biased to user location) ────────────────────────
  static Future<List<PlaceSuggestion>> getAutocompleteSuggestions(
    String input, {
    String? sessionToken,
    LatLng? locationBias,
  }) async {
    if (input.trim().isEmpty) return [];

    String url =
        '$_baseUrl/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&key=$_apiKey';

    if (sessionToken != null) url += '&sessiontoken=$sessionToken';
    if (locationBias != null) {
      url +=
          '&location=${locationBias.latitude},${locationBias.longitude}'
          '&radius=2000';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];
    final data = json.decode(response.body);
    if (data['status'] != 'OK') return [];

    return (data['predictions'] as List)
        .map(
          (p) => PlaceSuggestion(
            placeId: p['place_id'],
            description: p['description'],
          ),
        )
        .toList();
  }

  // ─── Place Detail → LatLng ────────────────────────────────────────────────
  static Future<LatLng?> getPlaceLatLng(
    String placeId, {
    String? sessionToken,
  }) async {
    String url =
        '$_baseUrl/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_apiKey';
    if (sessionToken != null) url += '&sessiontoken=$sessionToken';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    if (data['status'] != 'OK') return null;

    final loc = data['result']['geometry']['location'];
    return LatLng(loc['lat'], loc['lng']);
  }

  // ─── Walking Directions with full steps ───────────────────────────────────
  static Future<RouteResult?> getWalkingDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url =
        '$_baseUrl/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=walking'
        '&key=$_apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    if (data['status'] != 'OK') return null;

    final route = data['routes'][0];
    final leg = route['legs'][0];

    final pp = PolylinePoints();
    final points =
        pp
            .decodePolyline(route['overview_polyline']['points'])
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

    final steps =
        (leg['steps'] as List).map((step) {
          final stepPoints =
              pp
                  .decodePolyline(step['polyline']['points'])
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList();
          return RouteStep(
            instruction: _stripHtml(step['html_instructions'] ?? ''),
            distance: step['distance']['text'],
            distanceMeters: step['distance']['value'],
            duration: step['duration']['text'],
            startLocation: LatLng(
              step['start_location']['lat'],
              step['start_location']['lng'],
            ),
            endLocation: LatLng(
              step['end_location']['lat'],
              step['end_location']['lng'],
            ),
            maneuver: step['maneuver'] ?? '',
            polylinePoints: stepPoints,
          );
        }).toList();

    return RouteResult(
      polylinePoints: points,
      distance: leg['distance']['text'],
      duration: leg['duration']['text'],
      steps: steps,
    );
  }

  static String _stripHtml(String html) =>
      html
          .replaceAll(RegExp(r'<b>'), '')
          .replaceAll(RegExp(r'</b>'), '')
          .replaceAll(RegExp(r'<div[^>]*>'), '. ')
          .replaceAll(RegExp(r'</div>'), '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
}

// ─── Models ──────────────────────────────────────────────────────────────────

class PlaceSuggestion {
  final String placeId;
  final String description;
  const PlaceSuggestion({required this.placeId, required this.description});
}

class RouteStep {
  final String instruction;
  final String distance;
  final int distanceMeters;
  final String duration;
  final LatLng startLocation;
  final LatLng endLocation;
  final String maneuver;
  final List<LatLng> polylinePoints;

  const RouteStep({
    required this.instruction,
    required this.distance,
    required this.distanceMeters,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
    required this.maneuver,
    required this.polylinePoints,
  });

  String get ttsPrefix {
    switch (maneuver) {
      case 'turn-left':
        return 'Turn left';
      case 'turn-right':
        return 'Turn right';
      case 'turn-slight-left':
        return 'Slight left';
      case 'turn-slight-right':
        return 'Slight right';
      case 'turn-sharp-left':
        return 'Sharp left';
      case 'turn-sharp-right':
        return 'Sharp right';
      case 'uturn-left':
      case 'uturn-right':
        return 'Make a U-turn';
      case 'roundabout-left':
      case 'roundabout-right':
        return 'At the roundabout';
      case 'straight':
        return 'Continue straight';
      default:
        return '';
    }
  }

  /// Icon for the maneuver arrow shown in the nav banner
  String get maneuverIcon {
    if (maneuver.contains('left')) return '↰';
    if (maneuver.contains('right')) return '↱';
    if (maneuver.contains('uturn')) return '↩';
    if (maneuver.contains('roundabout')) return '↻';
    return '↑';
  }

  String get ttsAnnouncement {
    final prefix = ttsPrefix;
    return prefix.isEmpty ? instruction : '$prefix. $instruction in $distance';
  }
}

class RouteResult {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final List<RouteStep> steps;

  const RouteResult({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.steps,
  });
}
