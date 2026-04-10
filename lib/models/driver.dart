class Driver {
  final String id;
  final String name;

  const Driver({required this.id, required this.name});

  factory Driver.fromFirestore(Map<String, dynamic> data, String id) {
    return Driver(id: id, name: data['name'] as String? ?? '');
  }

  Map<String, dynamic> toMap() => {'name': name};

  @override
  bool operator ==(Object other) => other is Driver && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
