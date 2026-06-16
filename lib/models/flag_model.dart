import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// FlagModel
// Firestore collection: /flags/{reportId_userId}
// One document per user per report — prevents double flagging
// At 5 flags: report.status auto-changes to 'flagged'
// ============================================================

enum FlagReason {
  falseReport,
  spam,
  offensive,
  targetedAttack,
  other,
}

class FlagModel {
  final String id;        // Composite: reportId_userId
  final String reportId;
  final String userId;    // Firebase UID of user who flagged
  final FlagReason reason;
  final DateTime createdAt;

  const FlagModel({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.reason,
    required this.createdAt,
  });

  // ── Build composite ID ────────────────────────────────────
  static String buildId(String reportId, String userId) {
    return '${reportId}_$userId';
  }

  // ── Convert TO Firestore map ──────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'reportId':  reportId,
      'userId':    userId,
      'reason':    reason.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Create FROM Firestore document ────────────────────────
  factory FlagModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlagModel(
      id:         doc.id,
      reportId:   data['reportId']  ?? '',
      userId:     data['userId']    ?? '',
      reason:     _parseReason(data['reason']),
      createdAt:  data['createdAt'] != null
                    ? (data['createdAt'] as Timestamp).toDate()
                    : DateTime.now(),
    );
  }

  // ── Parse reason string to enum ───────────────────────────
  static FlagReason _parseReason(String? value) {
    switch (value) {
      case 'spam':             return FlagReason.spam;
      case 'offensive':        return FlagReason.offensive;
      case 'targeted_attack':  return FlagReason.targetedAttack;
      case 'other':            return FlagReason.other;
      default:                 return FlagReason.falseReport;
    }
  }

  // ── Display text for each reason ─────────────────────────
  String get reasonDisplayText {
    switch (reason) {
      case FlagReason.falseReport:     return 'False or misleading report';
      case FlagReason.spam:             return 'Spam or repeated content';
      case FlagReason.offensive:        return 'Offensive or abusive content';
      case FlagReason.targetedAttack:  return 'Personal attack on individual';
      case FlagReason.other:            return 'Other reason';
    }
  }

  @override
  String toString() => 'FlagModel(reportId: $reportId, reason: ${reason.name})';
}
