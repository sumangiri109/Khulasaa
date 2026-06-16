import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// HotspotModel
// Firestore collection: /hotspots/{hotspotId}
// Generated NIGHTLY by Python K-Means clustering
// Entire collection replaced every night — never manually created
// Used to draw circles on map screen
// Bigger intensity = bigger circle on map
// ============================================================

class HotspotModel {
  final String hotspotId;
  final int clusterId;              // K-Means cluster number
  final double lat;                 // Cluster center latitude
  final double lng;                 // Cluster center longitude
  final int intensity;              // Report count — determines circle size
  final int reportCount;            // Same as intensity — explicit
  final String? dominantCategory;  // Most common category in cluster
  final String? topDistrict;       // District with most reports
  final List<String> institutionIds; // Institutions in this cluster
  final DateTime updatedAt;        // When Python last ran

  const HotspotModel({
    required this.hotspotId,
    required this.clusterId,
    required this.lat,
    required this.lng,
    required this.intensity,
    required this.reportCount,
    this.dominantCategory,
    this.topDistrict,
    required this.institutionIds,
    required this.updatedAt,
  });

  // ── Convert TO Firestore map ──────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'clusterId':         clusterId,
      'lat':               lat,
      'lng':               lng,
      'intensity':         intensity,
      'reportCount':       reportCount,
      'dominantCategory':  dominantCategory,
      'topDistrict':       topDistrict,
      'institutionIds':    institutionIds,
      'updatedAt':         Timestamp.fromDate(updatedAt),
    };
  }

  // ── Create FROM Firestore document ────────────────────────
  factory HotspotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HotspotModel(
      hotspotId:        doc.id,
      clusterId:        data['clusterId']        ?? 0,
      lat:              (data['lat'] as num).toDouble(),
      lng:              (data['lng'] as num).toDouble(),
      intensity:        data['intensity']         ?? 0,
      reportCount:      data['reportCount']       ?? 0,
      dominantCategory: data['dominantCategory'],
      topDistrict:      data['topDistrict'],
      institutionIds:   data['institutionIds'] != null
                          ? List<String>.from(data['institutionIds'])
                          : [],
      updatedAt:        data['updatedAt'] != null
                          ? (data['updatedAt'] as Timestamp).toDate()
                          : DateTime.now(),
    );
  }

  // ── Circle radius for map (in metres) ────────────────────
  // More reports = bigger circle
  double get mapCircleRadius {
    if (intensity <= 5)   return 1000;
    if (intensity <= 15)  return 2000;
    if (intensity <= 30)  return 3500;
    if (intensity <= 50)  return 5000;
    return 7000;
  }

  @override
  String toString() {
    return 'HotspotModel('
        'id: $hotspotId, '
        'intensity: $intensity, '
        'district: $topDistrict'
        ')';
  }
}
