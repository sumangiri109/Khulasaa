import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/institution_model.dart';
import 'firestore_service.dart';

// ============================================================
// InstitutionService
//
// Handles:
// 1. Auto-creating an institution document when the FIRST
//    report is filed against a new office name (since users
//    type the office name freely — see Decision 1 design)
// 2. Fetching institution scorecard data
// 3. Searching institutions by name / district / category
// 4. "Most reported this week" for the search screen
//
// NOTE: transparencyScore, avgBribeAmount, lastInsight, and
// trendData are NEVER written by this service — those are
// updated exclusively by the Python nightly AI job. This
// service only manages the structural/count fields.
// ============================================================

class InstitutionService {
  static final InstitutionService _instance = InstitutionService._internal();
  factory InstitutionService() => _instance;
  InstitutionService._internal();

  final FirestoreService _firestore = FirestoreService();

  // ════════════════════════════════════════════════════════
  // FIND OR CREATE INSTITUTION
  // Called from the report form BEFORE submitReport() in
  // ReportService — ensures an institutionId always exists,
  // whether the office is brand new or already known.
  //
  // Matching strategy: exact name + district match (case
  // insensitive). Good enough for MVP; can be upgraded to
  // fuzzy matching later if duplicate office entries become
  // a problem (e.g. "Kavre Land Office" vs "kavre land office").
  // ════════════════════════════════════════════════════════
  Future<String> findOrCreateInstitution({
    required String name,
    required String categoryId,
    required String district,
    String? province,
    double? lat,
    double? lng,
  }) async {
    final normalizedName = name.trim();

    // ── Search for existing match ─────────────────────────────
    final existing = await _firestore.institutions
        .where('district', isEqualTo: district)
        .where('name', isEqualTo: normalizedName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // ── No match found — create a new institution ─────────────
    final ref = _firestore.institutions.doc();
    final now = DateTime.now();

    final institution = InstitutionModel(
      institutionId:            ref.id,
      name:                     normalizedName,
      categoryId:               categoryId,
      district:                 district,
      province:                 province,
      lat:                      lat,
      lng:                      lng,
      totalReports:             0,
      infrastructureReports:    0,
      institutionalReports:     0,
      personalReports:          0,
      ciaaVerifiedReports:      0,
      totalUpvotes:             0,
      transparencyScore:        100, // starts perfect, drops with verified reports
      avgBribeAmount:           null,
      mostCommonCorruptionType: null,
      lastInsight:              null,
      trend:                    InstitutionTrend.insufficientData,
      trendData:                [],
      updatedAt:                now,
      createdAt:                now,
    );

    await ref.set(institution.toMap());
    return ref.id;
  }

  // ════════════════════════════════════════════════════════
  // GET SINGLE INSTITUTION — for scorecard screen
  // ════════════════════════════════════════════════════════
  Future<InstitutionModel?> getInstitutionById(String institutionId) async {
    final doc = await _firestore.institutions.doc(institutionId).get();
    if (!doc.exists) return null;
    return InstitutionModel.fromFirestore(doc);
  }

  // ── Stream version — scorecard updates live after nightly AI run ─
  Stream<InstitutionModel?> watchInstitution(String institutionId) {
    return _firestore.institutions.doc(institutionId).snapshots().map(
        (doc) => doc.exists ? InstitutionModel.fromFirestore(doc) : null);
  }

  // ════════════════════════════════════════════════════════
  // SEARCH INSTITUTIONS BY NAME (prefix search)
  // Used by the Search screen's institution search bar
  // ════════════════════════════════════════════════════════
  Future<List<InstitutionModel>> searchByName(String query) async {
    if (query.trim().isEmpty) return [];

    final snap = await _firestore.institutions
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(15)
        .get();

    return snap.docs.map((doc) => InstitutionModel.fromFirestore(doc)).toList();
  }

  // ════════════════════════════════════════════════════════
  // GET INSTITUTIONS BY CATEGORY — for category filter chips
  // ════════════════════════════════════════════════════════
  Future<List<InstitutionModel>> getByCategory(
    String categoryId, {
    int limit = 20,
  }) async {
    final snap = await _firestore.institutions
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('totalReports', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) => InstitutionModel.fromFirestore(doc)).toList();
  }

  // ════════════════════════════════════════════════════════
  // GET INSTITUTIONS BY DISTRICT — for map filter
  // ════════════════════════════════════════════════════════
  Future<List<InstitutionModel>> getByDistrict(
    String district, {
    int limit = 50,
  }) async {
    final snap = await _firestore.institutions
        .where('district', isEqualTo: district)
        .orderBy('transparencyScore') // worst score first
        .limit(limit)
        .get();

    return snap.docs.map((doc) => InstitutionModel.fromFirestore(doc)).toList();
  }

  // ════════════════════════════════════════════════════════
  // MOST REPORTED THIS WEEK — for Search screen homepage
  // ════════════════════════════════════════════════════════
  Future<List<InstitutionModel>> getMostReportedThisWeek({int limit = 5}) async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    final snap = await _firestore.institutions
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
        .orderBy('updatedAt', descending: true)
        .orderBy('totalReports', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) => InstitutionModel.fromFirestore(doc)).toList();
  }

  // ════════════════════════════════════════════════════════
  // GET WORST SCORING INSTITUTIONS — for map/leaderboard view
  // Lower transparencyScore = more corruption reported
  // ════════════════════════════════════════════════════════
  Future<List<InstitutionModel>> getLowestScoring({int limit = 10}) async {
    final snap = await _firestore.institutions
        .orderBy('transparencyScore') // ascending — worst first
        .limit(limit)
        .get();

    return snap.docs.map((doc) => InstitutionModel.fromFirestore(doc)).toList();
  }

  // ════════════════════════════════════════════════════════
  // UPDATE TOTAL UPVOTES on institution — called after a
  // report belonging to it gets upvoted (keeps aggregate
  // in sync for scorecard display)
  // ════════════════════════════════════════════════════════
  Future<void> incrementTotalUpvotes(String institutionId, int delta) async {
    await _firestore.institutions.doc(institutionId).update({
      'totalUpvotes': _firestore.increment(delta),
      'updatedAt':    Timestamp.fromDate(DateTime.now()),
    });
  }

  // ════════════════════════════════════════════════════════
  // INCREMENT CIAA VERIFIED COUNT — called by CiaaReviewService
  // when a personal accusation against this institution is
  // confirmed guilty. Used for research paper statistics too.
  // ════════════════════════════════════════════════════════
  Future<void> incrementCiaaVerifiedCount(String institutionId) async {
    await _firestore.institutions.doc(institutionId).update({
      'ciaaVerifiedReports': _firestore.increment(1),
      'updatedAt':           Timestamp.fromDate(DateTime.now()),
    });
  }
}
