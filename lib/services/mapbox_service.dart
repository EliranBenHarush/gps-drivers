import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../models/route_stop.dart';
import '../models/nav_step.dart';

class MapboxService {
  static const _baseUrl = 'https://api.mapbox.com';

  // ─── Geocoding: חיפוש כתובת → קואורדינטות ────────────────────────────────

  static Future<List<Map<String, dynamic>>> geocode(String query) async {
    if (query.trim().length < 2) return [];
    final encoded = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      '$_baseUrl/geocoding/v5/mapbox.places/$encoded.json'
      '?access_token=${AppConfig.mapboxToken}'
      '&language=he'
      '&country=IL'
      '&limit=5',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body) as Map<String, dynamic>;
      return (body['features'] as List).map((f) {
        final center = f['center'] as List;
        return {
          'name': f['place_name'] as String,
          'lng': (center[0] as num).toDouble(),
          'lat': (center[1] as num).toDouble(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Directions: מסלול + הוראות ניווט ────────────────────────────────────

  static Future<DirectionsResult?> getDirections(List<RouteStop> stops) async {
    if (stops.length < 2) return null;

    final coords = stops.map((s) => '${s.lng},${s.lat}').join(';');
    final url = Uri.parse(
      '$_baseUrl/directions/v5/mapbox/driving/$coords'
      '?access_token=${AppConfig.mapboxToken}'
      '&geometries=geojson'
      '&steps=true'
      '&language=he'
      '&overview=full',
    );

    try {
      final res = await http.get(url);
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;

      final routePoints = (geometry['coordinates'] as List)
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      final steps = <NavStep>[];
      for (final leg in route['legs'] as List) {
        for (final step in (leg as Map)['steps'] as List) {
          steps.add(NavStep.fromJson(step as Map<String, dynamic>));
        }
      }

      return DirectionsResult(
        route: routePoints,
        steps: steps,
        totalDistance: (route['distance'] as num?)?.toDouble() ?? 0,
        totalDuration: (route['duration'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class DirectionsResult {
  final List<LatLng> route;
  final List<NavStep> steps;
  final double totalDistance;
  final double totalDuration;

  const DirectionsResult({
    required this.route,
    required this.steps,
    required this.totalDistance,
    required this.totalDuration,
  });

  String get distanceText {
    if (totalDistance >= 1000) {
      return '${(totalDistance / 1000).toStringAsFixed(1)} ק"מ';
    }
    return '${totalDistance.toInt()} מ׳';
  }

  String get durationText {
    if (totalDuration >= 3600) {
      final h = (totalDuration / 3600).floor();
      final m = ((totalDuration % 3600) / 60).floor();
      return '$h שע׳ $m דק׳';
    }
    return '${(totalDuration / 60).floor()} דק׳';
  }
}
