import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/upvoter_model.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

// ============================================================
// UpvoteService
//
// Handles the anonymous-safe upvoting system designed earlier:
// Document ID = reportId_userId (composite key)
// If that document EXISTS → already upvoted → ignore
// If it DOESN'T EXIST     → cast upvote → create the doc
//
// Uses a Firestore TRANSACTION so the check-then-write is
// atomic — prevents race conditions if a user double-taps
// the upvote button quickly.
// ============================================================

class UpvoteService {
  static final UpvoteService _instance = UpvoteService._internal();
  factory UpvoteService() => _instance;
  UpvoteService._internal();

  final FirestoreService _firestore = FirestoreService();
  final AuthService _auth = AuthService();

  // ════════════════════════════════════════════════════════
  // TOGGLE UPVOTE — call this when user taps the upvote button
  // Returns true if upvote was ADDED, false if it was REMOVED
  // (this method supports tap-to-toggle behaviour)
  // ════════════════════════════════════════════════════════
  Future<bool> toggleUpvote(String reportId) async {
    final uid = _auth.currentUserId;
    if (uid == null) {
      throw Exception('No active session — call AuthService.ensureSignedIn() first');
    }

    final upvoterId = UpvoterModel.buildId(reportId, uid);
    final upvoterRef = _firestore.upvoters.doc(upvoterId);
    final reportRef = _firestore.reports.doc(reportId);

    bool wasAdded = false;

    await _firestore.runTransaction((tx) async {
      final upvoterDoc = await tx.get(upvoterRef);
      final reportDoc = await tx.get(reportRef);

      if (!reportDoc.exists) {
        throw Exception('Report not found');
      }

      if (upvoterDoc.exists) {
        // ── Already upvoted → REMOVE the upvote (toggle off) ──
        tx.delete(upvoterRef);
        tx.update(reportRef, {
          'upvotes': _firestore.increment(-1),
        });
        wasAdded = false;
      } else {
        // ── Not yet upvoted → ADD the upvote (toggle on) ──────
        tx.set(upvoterRef, {
          'reportId':  reportId,
          'userId':    uid,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        tx.update(reportRef, {
          'upvotes': _firestore.increment(1),
        });
        wasAdded = true;
      }
    });

    // Update user's upvotesGiven counter (named users only)
    if (wasAdded) {
      await _auth.incrementUpvotesGiven(uid);
    }

    return wasAdded;
  }

  // ════════════════════════════════════════════════════════
  // CHECK IF CURRENT USER HAS UPVOTED A REPORT
  // Used by UI to show filled/unfilled upvote icon
  // ════════════════════════════════════════════════════════
  Future<bool> hasUpvoted(String reportId) async {
    final uid = _auth.currentUserId;
    if (uid == null) return false;

    final upvoterId = UpvoterModel.buildId(reportId, uid);
    final doc = await _firestore.upvoters.doc(upvoterId).get();
    return doc.exists;
  }

  // ── Stream version — for real-time icon state on feed cards ──
  Stream<bool> watchHasUpvoted(String reportId) {
    final uid = _auth.currentUserId;
    if (uid == null) return Stream.value(false);

    final upvoterId = UpvoterModel.buildId(reportId, uid);
    return _firestore.upvoters.doc(upvoterId).snapshots().map((doc) => doc.exists);
  }

  // ════════════════════════════════════════════════════════
  // GET ALL REPORT IDs THE CURRENT USER HAS UPVOTED
  // Useful for bulk-checking when rendering a feed list,
  // instead of calling hasUpvoted() once per card (N+1 problem)
  // ════════════════════════════════════════════════════════
  Future<Set<String>> getMyUpvotedReportIds() async {
    final uid = _auth.currentUserId;
    if (uid == null) return {};

    final snap = await _firestore.upvoters
        .where('userId', isEqualTo: uid)
        .get();

    return snap.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['reportId'] as String)
        .toSet();
  }
}
