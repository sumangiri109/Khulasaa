import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// InstitutionModel — Updated v2
// Firestore collection: /institutions/{institutionId}
// KEY CHANGE: Added corruptionReportCount breakdown by type
// and ciaaVerifiedCount for research paper data
// ============================================================

enum InstitutionTrend { increasing, decreasing, stable, insufficientData }

class TrendDataPoint {
  final String month;
  final int count;

  const TrendDataPoint({required this.month, required this.count});

  factory TrendDataPoint.fromMap(Map<String, dynamic> d) =>
      TrendDataPoint(month: d['month'] ?? '', count: d['count'] ?? 0);

  Map<String, dynamic> toMap() => {'month': month, 'count': count};
}

class InstitutionModel {
  final String institutionId;
  final String name;
  final String categoryId;
  final String district;
  final String? province;
  final double? lat;
  final double? lng;

  // ── Report counts breakdown ───────────────────────────
  final int totalReports;
  final int infrastructureReports; // Count by type
  final int institutionalReports;
  final int personalReports;
  final int ciaaVerifiedReports; // How many CIAA confirmed guilty
  final int totalUpvotes;

  // ── AI scorecard ──────────────────────────────────────
  final int transparencyScore; // 0-100, updated nightly
  final double? avgBribeAmount;
  final String? mostCommonCorruptionType;
  final String? lastInsight; // AI-generated summary
  final InstitutionTrend trend;
  final List<TrendDataPoint> trendData;

  final DateTime updatedAt;
  final DateTime createdAt;

  const InstitutionModel({
    required this.institutionId,
    required this.name,
    required this.categoryId,
    required this.district,
    this.province,
    this.lat,
    this.lng,
    required this.totalReports,
    required this.infrastructureReports,
    required this.institutionalReports,
    required this.personalReports,
    required this.ciaaVerifiedReports,
    required this.totalUpvotes,
    required this.transparencyScore,
    this.avgBribeAmount,
    this.mostCommonCorruptionType,
    this.lastInsight,
    required this.trend,
    required this.trendData,
    required this.updatedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'categoryId': categoryId,
    'district': district,
    'province': province,
    'lat': lat,
    'lng': lng,
    'totalReports': totalReports,
    'infrastructureReports': infrastructureReports,
    'institutionalReports': institutionalReports,
    'personalReports': personalReports,
    'ciaaVerifiedReports': ciaaVerifiedReports,
    'totalUpvotes': totalUpvotes,
    'transparencyScore': transparencyScore,
    'avgBribeAmount': avgBribeAmount,
    'mostCommonCorruptionType': mostCommonCorruptionType,
    'lastInsight': lastInsight,
    'trend': trend.name,
    'trendData': trendData.map((t) => t.toMap()).toList(),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory InstitutionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InstitutionModel(
      institutionId: doc.id,
      name: d['name'] ?? '',
      categoryId: d['categoryId'] ?? 'other',
      district: d['district'] ?? '',
      province: d['province'],
      lat: d['lat'] != null ? (d['lat'] as num).toDouble() : null,
      lng: d['lng'] != null ? (d['lng'] as num).toDouble() : null,
      totalReports: d['totalReports'] ?? 0,
      infrastructureReports: d['infrastructureReports'] ?? 0,
      institutionalReports: d['institutionalReports'] ?? 0,
      personalReports: d['personalReports'] ?? 0,
      ciaaVerifiedReports: d['ciaaVerifiedReports'] ?? 0,
      totalUpvotes: d['totalUpvotes'] ?? 0,
      transparencyScore: d['transparencyScore'] ?? 100,
      avgBribeAmount: d['avgBribeAmount'] != null
          ? (d['avgBribeAmount'] as num).toDouble()
          : null,
      mostCommonCorruptionType: d['mostCommonCorruptionType'],
      lastInsight: d['lastInsight'],
      trend: _parseTrend(d['trend']),
      trendData: d['trendData'] != null
          ? (d['trendData'] as List)
                .map(
                  (t) => TrendDataPoint.fromMap(Map<String, dynamic>.from(t)),
                )
                .toList()
          : [],
      updatedAt: (d['updatedAt'] as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }

  static InstitutionTrend _parseTrend(String? v) {
    switch (v) {
      case 'increasing':
        return InstitutionTrend.increasing;
      case 'decreasing':
        return InstitutionTrend.decreasing;
      case 'stable':
        return InstitutionTrend.stable;
      default:
        return InstitutionTrend.insufficientData;
    }
  }

  String get scoreLabel {
    if (transparencyScore >= 70) return 'high';
    if (transparencyScore >= 40) return 'medium';
    return 'low';
  }

  String get trendText {
    switch (trend) {
      case InstitutionTrend.increasing:
        return '⬆️ Worsening';
      case InstitutionTrend.decreasing:
        return '⬇️ Improving';
      case InstitutionTrend.stable:
        return '➡️ Stable';
      case InstitutionTrend.insufficientData:
        return '📊 Insufficient data';
    }
  }

  @override
  String toString() =>
      'InstitutionModel('
      'id: $institutionId, name: $name, score: $transparencyScore)';
}
