import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// CiaaReviewModel — NEW in v2
// Firestore collection: /ciaa_reviews/{reviewId}
//
// Created automatically when a PERSONAL accusation report
// is submitted. Links to the report and tracks the entire
// CIAA investigation workflow.
//
// Flow:
// 1. Personal report submitted
// 2. CiaaReview document created (status: pending)
// 3. CIAA moderator logs into dashboard
// 4. Sees pending reviews, investigates
// 5. Marks as guilty or notGuilty
// 6. Report status updates accordingly
// ============================================================

enum CiaaReviewStatus {
  pending,     // Waiting for CIAA to pick up
  inReview,    // CIAA is actively investigating
  guilty,      // CIAA confirmed — report goes PUBLIC
  notGuilty,   // CIAA cleared — report stays PRIVATE
  deferred,    // Needs more evidence — reporter notified
}

enum CiaaReviewPriority {
  low,
  medium,
  high,
  critical,   // High-profile accusation, needs urgent review
}

class CiaaReviewModel {
  final String reviewId;
  final String reportId;       // FK → reports collection
  final String reportType;     // Always 'personal' — double check
  final String district;       // Where the corruption occurred
  final String categoryId;     // Which category of corruption

  // ── Accused person info (extracted by AI) ────────────
  final String? accusedName;       // Name detected by AI from report text
  final String? accusedPosition;   // Position/role if mentioned
  final String? accusedOffice;     // Office/institution

  // ── Review workflow ───────────────────────────────────
  final CiaaReviewStatus status;
  final CiaaReviewPriority priority;
  final String? assignedTo;        // CIAA moderator userId assigned to this
  final DateTime? assignedAt;      // When it was assigned

  // ── Evidence summary ──────────────────────────────────
  final bool hasPhotoEvidence;    // Does the report have photo?
  final bool hasNamedReporter;    // Did reporter disclose identity?
  final double? bribeAmount;      // Alleged bribe amount
  final int reportUpvotes;        // How many upvoted — indicates credibility

  // ── CIAA decision ─────────────────────────────────────
  final String? reviewerNote;      // CIAA reviewer's note (public if guilty)
  final String? internalNote;      // Internal note (never shown to public)
  final DateTime? decisionAt;      // When final decision was made
  final String? decidedBy;         // CIAA moderator userId who decided

  // ── Reporter notification ─────────────────────────────
  final bool reporterNotified;     // Was reporter informed of outcome?
  final DateTime? notifiedAt;

  // ── Timestamps ───────────────────────────────────────
  final DateTime createdAt;
  final DateTime updatedAt;

  const CiaaReviewModel({
    required this.reviewId,
    required this.reportId,
    required this.reportType,
    required this.district,
    required this.categoryId,
    this.accusedName,
    this.accusedPosition,
    this.accusedOffice,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.assignedAt,
    required this.hasPhotoEvidence,
    required this.hasNamedReporter,
    this.bribeAmount,
    required this.reportUpvotes,
    this.reviewerNote,
    this.internalNote,
    this.decisionAt,
    this.decidedBy,
    required this.reporterNotified,
    this.notifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Convert TO Firestore map ──────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'reportId':         reportId,
      'reportType':       reportType,
      'district':         district,
      'categoryId':       categoryId,
      'accusedName':      accusedName,
      'accusedPosition':  accusedPosition,
      'accusedOffice':    accusedOffice,
      'status':           status.name,
      'priority':         priority.name,
      'assignedTo':       assignedTo,
      'assignedAt':       assignedAt != null
                            ? Timestamp.fromDate(assignedAt!)
                            : null,
      'hasPhotoEvidence': hasPhotoEvidence,
      'hasNamedReporter': hasNamedReporter,
      'bribeAmount':      bribeAmount,
      'reportUpvotes':    reportUpvotes,
      'reviewerNote':     reviewerNote,
      'internalNote':     internalNote,
      'decisionAt':       decisionAt != null
                            ? Timestamp.fromDate(decisionAt!)
                            : null,
      'decidedBy':        decidedBy,
      'reporterNotified': reporterNotified,
      'notifiedAt':       notifiedAt != null
                            ? Timestamp.fromDate(notifiedAt!)
                            : null,
      'createdAt':        Timestamp.fromDate(createdAt),
      'updatedAt':        Timestamp.fromDate(updatedAt),
    };
  }

  // ── Create FROM Firestore document ────────────────────
  factory CiaaReviewModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CiaaReviewModel(
      reviewId:         doc.id,
      reportId:         d['reportId']        ?? '',
      reportType:       d['reportType']      ?? 'personal',
      district:         d['district']        ?? '',
      categoryId:       d['categoryId']      ?? 'other',
      accusedName:      d['accusedName'],
      accusedPosition:  d['accusedPosition'],
      accusedOffice:    d['accusedOffice'],
      status:           _parseStatus(d['status']),
      priority:         _parsePriority(d['priority']),
      assignedTo:       d['assignedTo'],
      assignedAt:       d['assignedAt'] != null
                          ? (d['assignedAt'] as Timestamp).toDate()
                          : null,
      hasPhotoEvidence: d['hasPhotoEvidence'] ?? false,
      hasNamedReporter: d['hasNamedReporter'] ?? false,
      bribeAmount:      d['bribeAmount'] != null
                          ? (d['bribeAmount'] as num).toDouble()
                          : null,
      reportUpvotes:    d['reportUpvotes']   ?? 0,
      reviewerNote:     d['reviewerNote'],
      internalNote:     d['internalNote'],
      decisionAt:       d['decisionAt'] != null
                          ? (d['decisionAt'] as Timestamp).toDate()
                          : null,
      decidedBy:        d['decidedBy'],
      reporterNotified: d['reporterNotified'] ?? false,
      notifiedAt:       d['notifiedAt'] != null
                          ? (d['notifiedAt'] as Timestamp).toDate()
                          : null,
      createdAt:        (d['createdAt'] as Timestamp).toDate(),
      updatedAt:        (d['updatedAt'] as Timestamp).toDate(),
    );
  }

  // ── Enum parsers ──────────────────────────────────────
  static CiaaReviewStatus _parseStatus(String? v) {
    switch (v) {
      case 'inReview':   return CiaaReviewStatus.inReview;
      case 'guilty':     return CiaaReviewStatus.guilty;
      case 'notGuilty':  return CiaaReviewStatus.notGuilty;
      case 'deferred':   return CiaaReviewStatus.deferred;
      default:           return CiaaReviewStatus.pending;
    }
  }

  static CiaaReviewPriority _parsePriority(String? v) {
    switch (v) {
      case 'high':     return CiaaReviewPriority.high;
      case 'critical': return CiaaReviewPriority.critical;
      case 'low':      return CiaaReviewPriority.low;
      default:         return CiaaReviewPriority.medium;
    }
  }

  // ── Computed helpers ──────────────────────────────────

  // Is this review resolved?
  bool get isResolved =>
      status == CiaaReviewStatus.guilty ||
      status == CiaaReviewStatus.notGuilty;

  // Days since submitted
  int get daysPending =>
      DateTime.now().difference(createdAt).inDays;

  // Is this overdue? (more than 3 days pending)
  bool get isOverdue =>
      !isResolved && daysPending > 3;

  // Priority label for dashboard UI
  String get priorityLabel {
    switch (priority) {
      case CiaaReviewPriority.critical: return '🔴 Critical';
      case CiaaReviewPriority.high:     return '🟠 High';
      case CiaaReviewPriority.medium:   return '🟡 Medium';
      case CiaaReviewPriority.low:      return '🟢 Low';
    }
  }

  // Status label for dashboard
  String get statusLabel {
    switch (status) {
      case CiaaReviewStatus.pending:    return '⏳ Pending';
      case CiaaReviewStatus.inReview:   return '🔍 In Review';
      case CiaaReviewStatus.guilty:     return '✅ Guilty — Published';
      case CiaaReviewStatus.notGuilty:  return '❌ Not Guilty — Private';
      case CiaaReviewStatus.deferred:   return '📋 Deferred — More Evidence Needed';
    }
  }

  // copyWith
  CiaaReviewModel copyWith({
    CiaaReviewStatus?  status,
    CiaaReviewPriority? priority,
    String?            assignedTo,
    DateTime?          assignedAt,
    String?            reviewerNote,
    String?            internalNote,
    DateTime?          decisionAt,
    String?            decidedBy,
    bool?              reporterNotified,
    DateTime?          notifiedAt,
    DateTime?          updatedAt,
    int?               reportUpvotes,
  }) {
    return CiaaReviewModel(
      reviewId:         reviewId,
      reportId:         reportId,
      reportType:       reportType,
      district:         district,
      categoryId:       categoryId,
      accusedName:      accusedName,
      accusedPosition:  accusedPosition,
      accusedOffice:    accusedOffice,
      status:           status           ?? this.status,
      priority:         priority         ?? this.priority,
      assignedTo:       assignedTo       ?? this.assignedTo,
      assignedAt:       assignedAt       ?? this.assignedAt,
      hasPhotoEvidence: hasPhotoEvidence,
      hasNamedReporter: hasNamedReporter,
      bribeAmount:      bribeAmount,
      reportUpvotes:    reportUpvotes    ?? this.reportUpvotes,
      reviewerNote:     reviewerNote     ?? this.reviewerNote,
      internalNote:     internalNote     ?? this.internalNote,
      decisionAt:       decisionAt       ?? this.decisionAt,
      decidedBy:        decidedBy        ?? this.decidedBy,
      reporterNotified: reporterNotified ?? this.reporterNotified,
      notifiedAt:       notifiedAt       ?? this.notifiedAt,
      createdAt:        createdAt,
      updatedAt:        updatedAt        ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'CiaaReviewModel('
      'id: $reviewId, '
      'status: ${status.name}, '
      'accused: $accusedName, '
      'priority: ${priority.name}'
      ')';
}
