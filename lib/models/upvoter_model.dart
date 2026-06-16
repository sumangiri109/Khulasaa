import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// UpvoterModel
// Firestore collection: /upvoters/{reportId_userId}
// Document ID is composite: reportId + "_" + userId
// If this document EXISTS → user already upvoted this report
// If it DOESN'T EXIST   → user has not yet upvoted
// This is the ONLY mechanism preventing duplicate upvotes
// ============================================================

class UpvoterModel {
  final String id;        // Composite: reportId_userId
  final String reportId;
  final String userId;    // Firebase anonymous UID
  final DateTime createdAt;

  const UpvoterModel({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.createdAt,
  });

  // ── Build composite ID (use this everywhere) ──────────────
  static String buildId(String reportId, String userId) {
    return '${reportId}_$userId';
  }

  // ── Convert TO Firestore map ──────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'reportId':  reportId,
      'userId':    userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Create FROM Firestore document ────────────────────────
  factory UpvoterModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UpvoterModel(
      id:         doc.id,
      reportId:   data['reportId']  ?? '',
      userId:     data['userId']    ?? '',
      createdAt:  data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.now(),
    );
  }

  @override
  String toString() => 'UpvoterModel(reportId: $reportId, userId: $userId)';
}
