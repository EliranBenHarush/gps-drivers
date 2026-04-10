import 'package:latlong2/latlong.dart';

class NavStep {
  final String instruction;
  final double distance; // meters
  final double duration; // seconds
  final String maneuverType;
  final List<LatLng> points;

  const NavStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuverType,
    required this.points,
  });

  factory NavStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] as Map<String, dynamic>;
    final geometry = json['geometry'] as Map<String, dynamic>;
    final coords = (geometry['coordinates'] as List)
        .map((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();

    return NavStep(
      instruction: maneuver['instruction'] as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      maneuverType: maneuver['type'] as String? ?? '',
      points: coords,
    );
  }

  String get distanceText {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} ק"מ';
    }
    return '${distance.toInt()} מ׳';
  }

  String get durationText {
    if (duration >= 3600) {
      final h = (duration / 3600).floor();
      final m = ((duration % 3600) / 60).floor();
      return '$h שע׳ $m דק׳';
    }
    return '${(duration / 60).floor()} דק׳';
  }
}
