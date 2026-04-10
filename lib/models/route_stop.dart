class RouteStop {
  final String id;
  final String address;
  final double lat;
  final double lng;
  final int order;

  const RouteStop({
    required this.id,
    required this.address,
    required this.lat,
    required this.lng,
    required this.order,
  });

  factory RouteStop.fromMap(Map<String, dynamic> map) {
    return RouteStop(
      id: map['id'] as String? ?? '',
      address: map['address'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'address': address,
        'lat': lat,
        'lng': lng,
        'order': order,
      };

  RouteStop copyWith({int? order}) => RouteStop(
        id: id,
        address: address,
        lat: lat,
        lng: lng,
        order: order ?? this.order,
      );
}
