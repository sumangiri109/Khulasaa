import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/report_model.dart';
import '../models/ciaa_review_model.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

// ============================================================
// ReportService
// THE CORE SERVICE of Khulasaa.
//
// Handles:
// 1. Submitting a new report (with photo upload)
// 2. Routing logic — personal accusations go to CIAA review,
//    infrastructure/institutional go straight to public feed
// 3. Fetching the public feed (excludes pendingCiaa reports)
// 4. Retracting a report (not deleting — see design decision)
// 5. Fetching a single report detail
// 6. Fetching reports for a specific institution
//
// IMPORTANT: This service does NOT call the AI spam/duplicate
// checker directly — that happens in AIService, called from
// the UI BEFORE this service's submitReport() is invoked.
// This keeps ReportService focused purely on Firestore logic.
// ============================================================

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ════════════════════════════════════════════════════════
  // SUBMIT REPORT — the most important method in the app
  //
  // Call order expected from UI:
  // 1. UI collects form data (Steps 1-3 of report form)
  // 2. UI calls AIService.checkReport() — spam/duplicate/abuse
  // 3. If AI check passes, UI calls AIService.extractReportData()
  //    to get AiExtractedData (category, type, person name etc)
  // 4. UI calls THIS method with the final report data
  // ════════════════════════════════════════════════════════
  Future<ReportModel> submitReport({
    required String institutionId,
    required String institutionName,
    required String categoryId,
    required String district,
    String? province,
    required String description,
    double? bribeAmount,
    required DateTime incidentDate,
    double? lat,
    double? lng,
    required ReportType reportType,
    required CorruptionType corruptionType,
    required bool wasSpeechInput,
    String? originalSpeechTranscript,
    AiExtractedData? aiExtracted,
    required bool isNamed,
    File? photoFile,
  }) async {
    final uid = _auth.currentUserId;
    if (uid == null) {
      throw Exception('No active session — call AuthService.ensureSignedIn() first');
    }

    // ── Validate description length (matches DB constraint) ──
    if (description.trim().length < 50) {
      throw Exception('Description must be at least 50 characters');
    }

    // ── Resolve identity for this report ──────────────────────
    String? userName;
    if (isNamed) {
      final profile = await _auth.getCurrentUserProfile();
      if (profile == null || !profile.identityDisclosed) {
        throw Exception(
          'Cannot post as named user — identity not disclosed in Settings yet'
        );
      }
      userName = profile.displayName; // snapshot at time of posting
    }

    // ── Upload photo if provided ──────────────────────────────
    String? photoUrl;
    if (photoFile != null) {
      photoUrl = await _uploadEvidencePhoto(uid, photoFile);
    }

    // ── Determine initial status based on report type ────────
    // THIS IS THE CORE ROUTING LOGIC your supervisor designed:
    //   personal       → pendingCiaa (NOT public yet)
    //   institutional  → active (public after AI check passed)
    //   infrastructure → active (public immediately)
    final initialStatus = reportType == ReportType.personal
        ? ReportStatus.pendingCiaa
        : ReportStatus.active;

    // ── Build the report document reference (get ID first) ───
    final reportRef = _firestore.reports.doc();

    final report = ReportModel(
      reportId:                 reportRef.id,
      institutionId:             institutionId,
      institutionName:           institutionName,
      categoryId:                categoryId,
      district:                  district,
      province:                  province,
      description:               description.trim(),
      bribeAmount:               bribeAmount,
      incidentDate:              incidentDate,
      lat:                       lat,
      lng:                       lng,
      reportType:                reportType,
      corruptionType:            corruptionType,
      wasSpeechInput:            wasSpeechInput,
      originalSpeechTranscript:  originalSpeechTranscript,
      aiExtracted:               aiExtracted,
      userId:                    uid,
      isNamed:                   isNamed,
      userName:                  userName,
      photoUrl:                  photoUrl,
      upvotes:                   0,
      flagCount:                 0,
      status:                    initialStatus,
      aiStatus:                  AiStatus.unverified, // set by AI service before this call
      aiCheckedAt:               DateTime.now(),
      createdAt:                 DateTime.now(), // overwritten by serverTimestamp in toMap()
    );

    // ── Write report to Firestore ─────────────────────────────
    await reportRef.set(report.toMap());

    // ── If personal accusation — create CIAA review document ──
    if (reportType == ReportType.personal) {
      await _createCiaaReview(
        reportId:         reportRef.id,
        district:          district,
        categoryId:        categoryId,
        accusedName:       aiExtracted?.detectedPersonName,
        accusedOffice:     institutionName,
        hasPhotoEvidence:  photoUrl != null,
        hasNamedReporter:  isNamed,
        bribeAmount:       bribeAmount,
      );

      // Link the review back to the report
      await reportRef.update({
        'ciaaSubmittedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    // ── Update institution's report counts ─────────────────────
    await _incrementInstitutionCounts(institutionId, reportType);

    // ── Update user's reportsCount (named users only) ──────────
    await _auth.incrementReportsCount(uid);

    return report;
  }

  // ── Upload photo evidence to Firebase Storage ───────────────
  Future<String> _uploadEvidencePhoto(String uid, File photoFile) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('evidence/$uid/$fileName');
    final uploadTask = await ref.putFile(photoFile);
    return await uploadTask.ref.getDownloadURL();
  }

  // ── Create the CIAA review document for personal accusations ─
  Future<void> _createCiaaReview({
    required String reportId,
    required String district,
    required String categoryId,
    String? accusedName,
    String? accusedOffice,
    required bool hasPhotoEvidence,
    required bool hasNamedReporter,
    double? bribeAmount,
  }) async {
    final reviewRef = _firestore.ciaaReviews.doc();
    final now = DateTime.now();

    // ── Auto-assign priority based on evidence strength ───────
    // This is a simple heuristic — can be refined by AI later
    CiaaReviewPriority priority = CiaaReviewPriority.medium;
    if (hasPhotoEvidence && hasNamedReporter) {
      priority = CiaaReviewPriority.high;
    } else if (!hasPhotoEvidence && !hasNamedReporter) {
      priority = CiaaReviewPriority.low;
    }

    final review = CiaaReviewModel(
      reviewId:          reviewRef.id,
      reportId:          reportId,
      reportType:        'personal',
      district:          district,
      categoryId:        categoryId,
      accusedName:       accusedName,
      accusedOffice:     accusedOffice,
      status:            CiaaReviewStatus.pending,
      priority:          priority,
      hasPhotoEvidence:  hasPhotoEvidence,
      hasNamedReporter:  hasNamedReporter,
      bribeAmount:       bribeAmount,
      reportUpvotes:     0,
      reporterNotified:  false,
      createdAt:         now,
      updatedAt:         now,
    );

    await reviewRef.set(review.toMap());

    // Link review ID back onto the report document
    await _firestore.reports.doc(reportId).update({
      'ciaaReviewId': reviewRef.id,
    });
  }

  // ── Update institution counts when a new report arrives ──────
  Future<void> _incrementInstitutionCounts(
    String institutionId,
    ReportType reportType,
  ) async {
    final fieldToIncrement = switch (reportType) {
      ReportType.infrastructure => 'infrastructureReports',
      ReportType.institutional  => 'institutionalReports',
      ReportType.personal       => 'personalReports',
    };

    final doc = await _firestore.institutions.doc(institutionId).get();
    if (doc.exists) {
      await _firestore.institutions.doc(institutionId).update({
        'totalReports':     _firestore.increment(1),
        fieldToIncrement:    _firestore.increment(1),
        'updatedAt':         Timestamp.fromDate(DateTime.now()),
      });
    }
    // If institution doesn't exist yet, InstitutionService creates it
    // (handled separately — see institution_service.dart)
  }

  // ════════════════════════════════════════════════════════
  // GET PUBLIC FEED
  // Only returns reports that are actually meant to be public:
  //   - status == active (infrastructure/institutional)
  //   - status == ciaaVerified (personal, CIAA-confirmed guilty)
  // NEVER returns pendingCiaa, ciaaRejected, retracted, removed
  // ════════════════════════════════════════════════════════
  Stream<List<ReportModel>> getPublicFeed({
    String? categoryFilter,
    String? districtFilter,
    int limit = 20,
  }) {
    Query query = _firestore.reports
        .where('status', whereIn: ['active', 'ciaaVerified'])
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (categoryFilter != null && categoryFilter != 'all') {
      query = query.where('categoryId', isEqualTo: categoryFilter);
    }
    if (districtFilter != null && districtFilter != 'all') {
      query = query.where('district', isEqualTo: districtFilter);
    }

    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => ReportModel.fromFirestore(doc)).toList());
  }

  // ── Get feed sorted by most upvoted ───────────────────────────
  Stream<List<ReportModel>> getMostUpvotedFeed({int limit = 20}) {
    return _firestore.reports
        .where('status', whereIn: ['active', 'ciaaVerified'])
        .orderBy('upvotes', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ReportModel.fromFirestore(doc)).toList());
  }

  // ════════════════════════════════════════════════════════
  // GET SINGLE REPORT — for report detail screen
  // ════════════════════════════════════════════════════════
  Future<ReportModel?> getReportById(String reportId) async {
    final doc = await _firestore.reports.doc(reportId).get();
    if (!doc.exists) return null;
    return ReportModel.fromFirestore(doc);
  }

  // ── Stream version — for real-time updates on detail screen ──
  Stream<ReportModel?> watchReport(String reportId) {
    return _firestore.reports.doc(reportId).snapshots().map(
        (doc) => doc.exists ? ReportModel.fromFirestore(doc) : null);
  }

  // ════════════════════════════════════════════════════════
  // GET REPORTS FOR AN INSTITUTION — for scorecard screen
  // ════════════════════════════════════════════════════════
  Stream<List<ReportModel>> getReportsByInstitution(
    String institutionId, {
    int limit = 50,
  }) {
    return _firestore.reports
        .where('institutionId', isEqualTo: institutionId)
        .where('status', whereIn: ['active', 'ciaaVerified'])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ReportModel.fromFirestore(doc)).toList());
  }

  // ════════════════════════════════════════════════════════
  // RETRACT REPORT — NOT delete (see design decision)
  // Only the original reporter can retract their own report.
  // Report stays in database for AI analysis, but disappears
  // from public feed.
  // ════════════════════════════════════════════════════════
  Future<void> retractReport(String reportId) async {
    final uid = _auth.currentUserId;
    if (uid == null) throw Exception('No active session');

    final doc = await _firestore.reports.doc(reportId).get();
    if (!doc.exists) throw Exception('Report not found');

    final report = ReportModel.fromFirestore(doc);
    if (report.userId != uid) {
      throw Exception('You can only retract your own reports');
    }

    final now = DateTime.now();
    await _firestore.reports.doc(reportId).update({
      'status':      ReportStatus.retracted.name,
      'retractedAt': Timestamp.fromDate(now),
      'updatedAt':   Timestamp.fromDate(now),
    });
  }

  // ════════════════════════════════════════════════════════
  // GET MY REPORTS — for user's own profile/history
  // ════════════════════════════════════════════════════════
  Stream<List<ReportModel>> getMyReports() {
    final uid = _auth.currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestore.reports
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ReportModel.fromFirestore(doc)).toList());
  }

  // ════════════════════════════════════════════════════════
  // SEARCH REPORTS — basic text search on description
  // NOTE: Firestore doesn't support full-text search natively.
  // For MVP this does a simple prefix search on institutionName.
  // For real search, integrate Algolia or similar later.
  // ════════════════════════════════════════════════════════
  Future<List<ReportModel>> searchByInstitutionName(String query) async {
    if (query.trim().isEmpty) return [];

    final snap = await _firestore.reports
        .where('status', whereIn: ['active', 'ciaaVerified'])
        .where('institutionName', isGreaterThanOrEqualTo: query)
        .where('institutionName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snap.docs.map((doc) => ReportModel.fromFirestore(doc)).toList();
  }
}
