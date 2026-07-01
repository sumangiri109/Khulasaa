import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ciaa_review_model.dart';
import '../models/report_model.dart';
import 'firestore_service.dart';
import 'auth_service.dart';
import 'institution_service.dart';

// ============================================================
// CiaaReviewService
//
// Powers the CIAA Moderator Dashboard — the verification layer
// your supervisor designed. This is what makes Khulasaa safe
// from defaming innocent people.
//
// Workflow:
// 1. Personal report submitted → CiaaReview created (pending)
// 2. CIAA moderator logs in, sees pending queue
// 3. Moderator picks up a review → status: inReview
// 4. Moderator investigates, makes decision:
//      GUILTY     → report becomes public (ciaaVerified)
//      NOT GUILTY → report stays private forever (ciaaRejected)
//      DEFERRED   → needs more evidence, reporter notified
// 5. Reporter gets notified of outcome either way
// ============================================================

class CiaaReviewService {
  static final CiaaReviewService _instance = CiaaReviewService._internal();
  factory CiaaReviewService() => _instance;
  CiaaReviewService._internal();

  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();
  final InstitutionService _institutionService = InstitutionService();

  // ════════════════════════════════════════════════════════
  // GET PENDING QUEUE — main dashboard view for CIAA officers
  // Sorted by priority (critical first), then oldest first
  // ════════════════════════════════════════════════════════
  Stream<List<CiaaReviewModel>> getPendingQueue({
    String? districtFilter,
    String? categoryFilter,
  }) {
    Query query = _firestore.ciaaReviews
        .where('status', whereIn: ['pending', 'inReview']);

    if (districtFilter != null && districtFilter != 'all') {
      query = query.where('district', isEqualTo: districtFilter);
    }
    if (categoryFilter != null && categoryFilter != 'all') {
      query = query.where('categoryId', isEqualTo: categoryFilter);
    }

    return query
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CiaaReviewModel.fromFirestore(doc))
            .toList()
          // Sort by priority client-side (critical → high → medium → low)
          ..sort((a, b) => _priorityWeight(b.priority)
              .compareTo(_priorityWeight(a.priority))));
  }

  int _priorityWeight(CiaaReviewPriority p) {
    switch (p) {
      case CiaaReviewPriority.critical: return 4;
      case CiaaReviewPriority.high:     return 3;
      case CiaaReviewPriority.medium:   return 2;
      case CiaaReviewPriority.low:      return 1;
    }
  }

  // ════════════════════════════════════════════════════════
  // GET OVERDUE REVIEWS — pending more than 3 days
  // Shown as an urgent alert section on dashboard
  // ════════════════════════════════════════════════════════
  Future<List<CiaaReviewModel>> getOverdueReviews() async {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

    final snap = await _firestore.ciaaReviews
        .where('status', whereIn: ['pending', 'inReview'])
        .where('createdAt', isLessThan: Timestamp.fromDate(threeDaysAgo))
        .get();

    return snap.docs.map((doc) => CiaaReviewModel.fromFirestore(doc)).toList();
  }

  // ════════════════════════════════════════════════════════
  // ASSIGN REVIEW TO A MODERATOR — picked up from queue
  // ════════════════════════════════════════════════════════
  Future<void> assignToModerator(String reviewId) async {
    final moderatorId = _auth.currentUserId;
    if (moderatorId == null) throw Exception('No active moderator session');

    final now = DateTime.now();
    await _firestore.ciaaReviews.doc(reviewId).update({
      'status':      CiaaReviewStatus.inReview.name,
      'assignedTo':  moderatorId,
      'assignedAt':  Timestamp.fromDate(now),
      'updatedAt':   Timestamp.fromDate(now),
    });
  }

  // ════════════════════════════════════════════════════════
  // DECIDE: GUILTY
  // — Report becomes PUBLIC with CIAA Verified badge
  // — Institution's ciaaVerifiedReports count increments
  // — Reporter gets notified (handled by NotificationService,
  //   called separately from the UI after this completes)
  // ════════════════════════════════════════════════════════
  Future<void> markGuilty({
    required String reviewId,
    required String reportId,
    required String reviewerNote, // shown publicly alongside verified report
  }) async {
    final moderatorId = _auth.currentUserId;
    if (moderatorId == null) throw Exception('No active moderator session');

    final now = DateTime.now();

    // ── Update the CIAA review document ───────────────────────
    await _firestore.ciaaReviews.doc(reviewId).update({
      'status':       CiaaReviewStatus.guilty.name,
      'reviewerNote': reviewerNote,
      'decisionAt':   Timestamp.fromDate(now),
      'decidedBy':    moderatorId,
      'updatedAt':    Timestamp.fromDate(now),
    });

    // ── Update the report — goes PUBLIC now ───────────────────
    await _firestore.reports.doc(reportId).update({
      'status':            ReportStatus.ciaaVerified.name,
      'ciaaResolvedAt':    Timestamp.fromDate(now),
      'ciaaReviewerNote':  reviewerNote,
      'updatedAt':         Timestamp.fromDate(now),
    });

    // ── Update institution's CIAA verified count ──────────────
    final reportDoc = await _firestore.reports.doc(reportId).get();
    if (reportDoc.exists) {
      final report = ReportModel.fromFirestore(reportDoc);
      await _institutionService.incrementCiaaVerifiedCount(report.institutionId);
    }

    // ── Update moderator's stats ──────────────────────────────
    await _updateModeratorStats(moderatorId, guilty: true);
  }

  // ════════════════════════════════════════════════════════
  // DECIDE: NOT GUILTY
  // — Report stays PRIVATE forever (ciaaRejected)
  // — Never shown on public feed, never visible to others
  // — Protects the accused person's reputation completely
  // ════════════════════════════════════════════════════════
  Future<void> markNotGuilty({
    required String reviewId,
    required String reportId,
    String? internalNote, // private note, never shown publicly
  }) async {
    final moderatorId = _auth.currentUserId;
    if (moderatorId == null) throw Exception('No active moderator session');

    final now = DateTime.now();

    await _firestore.ciaaReviews.doc(reviewId).update({
      'status':       CiaaReviewStatus.notGuilty.name,
      'internalNote': internalNote,
      'decisionAt':   Timestamp.fromDate(now),
      'decidedBy':    moderatorId,
      'updatedAt':    Timestamp.fromDate(now),
    });

    // Report stays hidden — status updated but never goes public
    await _firestore.reports.doc(reportId).update({
      'status':         ReportStatus.ciaaRejected.name,
      'ciaaResolvedAt': Timestamp.fromDate(now),
      'updatedAt':      Timestamp.fromDate(now),
    });

    await _updateModeratorStats(moderatorId, guilty: false);
  }

  // ════════════════════════════════════════════════════════
  // DECIDE: DEFERRED — needs more evidence
  // Report stays in pendingCiaa, reporter is asked for more info
  // ════════════════════════════════════════════════════════
  Future<void> deferReview({
    required String reviewId,
    required String internalNote,
  }) async {
    final moderatorId = _auth.currentUserId;
    if (moderatorId == null) throw Exception('No active moderator session');

    await _firestore.ciaaReviews.doc(reviewId).update({
      'status':       CiaaReviewStatus.deferred.name,
      'internalNote': internalNote,
      'updatedAt':    Timestamp.fromDate(DateTime.now()),
    });
    // Report status remains 'pendingCiaa' — stays out of public feed
  }

  // ── Internal — update moderator's review statistics ─────────
  Future<void> _updateModeratorStats(String moderatorId, {required bool guilty}) async {
    final updates = <String, dynamic>{
      'totalReviewed': _firestore.increment(1),
      'lastLoginAt':   Timestamp.fromDate(DateTime.now()),
    };
    if (guilty) {
      updates['totalGuilty'] = _firestore.increment(1);
    } else {
      updates['totalNotGuilty'] = _firestore.increment(1);
    }
    await _firestore.moderators.doc(moderatorId).update(updates);
  }

  // ════════════════════════════════════════════════════════
  // GET SINGLE REVIEW — for review detail screen
  // ════════════════════════════════════════════════════════
  Future<CiaaReviewModel?> getReviewById(String reviewId) async {
    final doc = await _firestore.ciaaReviews.doc(reviewId).get();
    if (!doc.exists) return null;
    return CiaaReviewModel.fromFirestore(doc);
  }

  // ── Stream version — live updates while reviewing ────────────
  Stream<CiaaReviewModel?> watchReview(String reviewId) {
    return _firestore.ciaaReviews.doc(reviewId).snapshots().map(
        (doc) => doc.exists ? CiaaReviewModel.fromFirestore(doc) : null);
  }

  // ════════════════════════════════════════════════════════
  // GET REVIEW BY REPORT ID — check status from report detail
  // (used to show "Under CIAA Review" badge to the reporter)
  // ════════════════════════════════════════════════════════
  Future<CiaaReviewModel?> getReviewByReportId(String reportId) async {
    final snap = await _firestore.ciaaReviews
        .where('reportId', isEqualTo: reportId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CiaaReviewModel.fromFirestore(snap.docs.first);
  }

  // ════════════════════════════════════════════════════════
  // RESEARCH PAPER STATS — aggregate numbers for documentation
  // Call this periodically to log methodology data
  // ════════════════════════════════════════════════════════
  Future<Map<String, int>> getResearchStats() async {
    final allReviews = await _firestore.ciaaReviews.get();
    int pending = 0, guilty = 0, notGuilty = 0, deferred = 0;

    for (final doc in allReviews.docs) {
      final review = CiaaReviewModel.fromFirestore(doc);
      switch (review.status) {
        case CiaaReviewStatus.pending:
        case CiaaReviewStatus.inReview:
          pending++;
          break;
        case CiaaReviewStatus.guilty:
          guilty++;
          break;
        case CiaaReviewStatus.notGuilty:
          notGuilty++;
          break;
        case CiaaReviewStatus.deferred:
          deferred++;
          break;
      }
    }

    return {
      'totalReviews': allReviews.docs.length,
      'pending':      pending,
      'guilty':       guilty,
      'notGuilty':    notGuilty,
      'deferred':     deferred,
    };
  }
}
