class RouteStop {
  final String id;
  final String address;
  final double lat;
  final double lng;
  final int order;
  final String phone1;
  final String phone2;
  final String balance;

  const RouteStop({
    required this.id,
    required this.address,
    required this.lat,
    required this.lng,
    required this.order,
    this.phone1 = '',
    this.phone2 = '',
    this.balance = '',
  });

  factory RouteStop.fromMap(Map<String, dynamic> map) {
    return RouteStop(
      id: map['id'] as String? ?? '',
      address: map['address'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      order: (map['order'] as num?)?.toInt() ?? 0,
      phone1: map['phone1'] as String? ?? '',
      phone2: map['phone2'] as String? ?? '',
      balance: map['balance'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'address': address,
        'lat': lat,
        'lng': lng,
        'order': order,
        'phone1': phone1,
        'phone2': phone2,
        'balance': balance,
      };

  RouteStop copyWith({
    int? order,
    String? phone1,
    String? phone2,
    String? balance,
  }) =>
      RouteStop(
        id: id,
        address: address,
        lat: lat,
        lng: lng,
        order: order ?? this.order,
        phone1: phone1 ?? this.phone1,
        phone2: phone2 ?? this.phone2,
        balance: balance ?? this.balance,
      );

  String get wazeUrl => 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
}
