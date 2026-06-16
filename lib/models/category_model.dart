import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// CategoryModel
// Firestore collection: /categories/{categoryId}
// Pre-loaded — never created by users
// Based on real CIAA Nepal corruption data
// ============================================================

class CategoryModel {
  final String categoryId;
  final String nameEn;          // English name
  final String nameNe;          // Nepali name (Devanagari)
  final String icon;            // Emoji icon
  final double? ciaaReportPercent; // Real CIAA % — null for 'other'
  final bool isActive;          // Whether shown in app
  final int sortOrder;          // Display order in filter chips

  const CategoryModel({
    required this.categoryId,
    required this.nameEn,
    required this.nameNe,
    required this.icon,
    this.ciaaReportPercent,
    required this.isActive,
    required this.sortOrder,
  });

  // ── Convert TO Firestore map ─────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'categoryId':         categoryId,
      'nameEn':             nameEn,
      'nameNe':             nameNe,
      'icon':               icon,
      'ciaaReportPercent':  ciaaReportPercent,
      'isActive':           isActive,
      'sortOrder':          sortOrder,
    };
  }

  // ── Create FROM Firestore document ───────────────────────
  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      categoryId:         doc.id,
      nameEn:             data['nameEn']             ?? '',
      nameNe:             data['nameNe']             ?? '',
      icon:               data['icon']               ?? '📋',
      ciaaReportPercent:  data['ciaaReportPercent'] != null
                            ? (data['ciaaReportPercent'] as num).toDouble()
                            : null,
      isActive:           data['isActive']           ?? true,
      sortOrder:          data['sortOrder']           ?? 99,
    );
  }

  // ── Create FROM Map ──────────────────────────────────────
  factory CategoryModel.fromMap(Map<String, dynamic> data) {
    return CategoryModel(
      categoryId:         data['categoryId']         ?? '',
      nameEn:             data['nameEn']             ?? '',
      nameNe:             data['nameNe']             ?? '',
      icon:               data['icon']               ?? '📋',
      ciaaReportPercent:  data['ciaaReportPercent'] != null
                            ? (data['ciaaReportPercent'] as num).toDouble()
                            : null,
      isActive:           data['isActive']           ?? true,
      sortOrder:          data['sortOrder']           ?? 99,
    );
  }

  // ── Get display name based on current language ───────────
  String getDisplayName(String languageCode) {
    return languageCode == 'ne' ? nameNe : nameEn;
  }

  @override
  String toString() => 'CategoryModel(categoryId: $categoryId, nameEn: $nameEn)';
}
