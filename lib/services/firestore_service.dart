import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver.dart';
import '../models/route_stop.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ─── נהגים ───────────────────────────────────────────────────────────────

  static Stream<List<Driver>> watchDrivers() {
    return _db.collection('drivers').orderBy('name').snapshots().map(
          (snap) => snap.docs
              .map((d) => Driver.fromFirestore(d.data(), d.id))
              .toList(),
        );
  }

  static Future<void> addDriver(String name) {
    return _db.collection('drivers').add({'name': name.trim()});
  }

  static Future<void> deleteDriver(String driverId) async {
    await _db.collection('drivers').doc(driverId).delete();
    await _db.collection('routes').doc(driverId).delete();
  }

  // ─── מסלולים ─────────────────────────────────────────────────────────────

  static Future<void> saveRoute(String driverId, List<RouteStop> stops) {
    return _db.collection('routes').doc(driverId).set({
      'stops': stops.map((s) => s.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<RouteStop>> watchRoute(String driverId) {
    return _db.collection('routes').doc(driverId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return <RouteStop>[];
      final list = (doc.data()!['stops'] as List? ?? [])
          .map((s) => RouteStop.fromMap(s as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  static Future<void> clearRoute(String driverId) {
    return _db.collection('routes').doc(driverId).delete();
  }
}
