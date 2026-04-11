import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route_stop.dart';
import '../models/nav_step.dart';

class MapboxService {
  // ─── Geocoding: Photon (Komoot, OpenStreetMap data, supports CORS) ──────────

  static Future<List<Map<String, dynamic>>> geocode(String query) async {
    if (query.trim().length < 2) return [];
    final encoded = Uri.encodeComponent(query.trim());
    // bbox = Israel bounding box: lon_min,lat_min,lon_max,lat_max
    // lat/lon = center of Israel as location bias; lang=he unsupported → omit
    final url = Uri.parse(
      'https://photon.komoot.io/api/'
      '?q=$encoded'
      '&limit=5'
      '&lat=31.5'
      '&lon=34.8',
    );
    try {
      final res = await http.get(url, headers: {
        'User-Agent': 'gps-drivers-app/1.0',
      });
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body) as Map<String, dynamic>;
      final features = (body['features'] as List?) ?? [];
      return features.map((f) {
        final props = f['properties'] as Map<String, dynamic>;
        final coords = (f['geometry']['coordinates'] as List);
        final name = _buildPhotonName(props);
        return {
          'name': name,
          'lng': (coords[0] as num).toDouble(),
          'lat': (coords[1] as num).toDouble(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static String _buildPhotonName(Map<String, dynamic> props) {
    final parts = <String>[];
    final street = props['street'] as String?;
    final housenumber = props['housenumber'] as String?;
    final name = props['name'] as String?;
    final city = props['city'] as String?;

    if (street != null) {
      parts.add(housenumber != null ? '$street $housenumber' : street);
    } else if (name != null) {
      parts.add(name);
    }
    if (city != null) parts.add(city);
    return parts.isNotEmpty ? parts.join(', ') : (props['display_name'] as String? ?? '');
  }

  // ─── Directions: OSRM (חינמי, ללא טוקן) ──────────────────────────────────

  static Future<DirectionsResult?> getDirections(List<RouteStop> stops) async {
    if (stops.length < 2) return null;

    final coords = stops.map((s) => '${s.lng},${s.lat}').join(';');
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coords'
      '?overview=full'
      '&geometries=geojson'
      '&steps=true',
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
          steps.add(NavStep.fromOsrm(step as Map<String, dynamic>));
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
