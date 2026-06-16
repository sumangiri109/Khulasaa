import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// ReportModel
// Firestore collection: /reports/{reportId}
// THE CORE MODEL — every corruption report filed
// This is the most critical model in the entire app
// ============================================================

// ── Report status enum — matches DB ENUM exactly ─────────
enum ReportStatus {
  active,     // live on feed — default
  retracted,  // hidden by author — stays in DB
  flagged,    // 5+ community flags — auto-hidden
  removed,    // admin removed permanently
}

// ── AI status enum — matches DB ENUM exactly ─────────────
enum AiStatus {
  verified,   // passed all checks + pattern match found
  unverified, // passed basic checks but no pattern yet
  flagged,    // AI detected issue
}

// ── Main ReportModel ──────────────────────────────────────
class ReportModel {
  final String reportId;
  final String institutionId;
  final String institutionName;   // Snapshot — never changes after post
  final String categoryId;        // Snapshot — never changes after post
  final String district;
  final String? province;
  final String description;       // Min 50 chars
  final double? bribeAmount;      // NPR — null if not provided
  final DateTime incidentDate;    // When bribery happened
  final double? lat;              // Where user submitted report
  final double? lng;
  final String userId;            // Firebase anonymous UID
  final bool isNamed;             // Did user show name on THIS report?
  final String? userName;         // Snapshot of name — null if anonymous
  final String? photoUrl;         // Firebase Storage URL — null if no photo
  final int upvotes;              // Community upvote count
  final int flagCount;            // Times flagged as false
  final ReportStatus status;      // active/retracted/flagged/removed
  final AiStatus aiStatus;        // verified/unverified/flagged
  final DateTime? aiCheckedAt;    // When AI filter ran
  final DateTime createdAt;       // Server timestamp on submit
  final DateTime? retractedAt;    // When user retracted — null if not
  final DateTime? updatedAt;      // Last modification time

  const ReportModel({
    required this.reportId,
    required this.institutionId,
    required this.institutionName,
    required this.categoryId,
    required this.district,
    this.province,
    required this.description,
    this.bribeAmount,
    required this.incidentDate,
    this.lat,
    this.lng,
    required this.userId,
    required this.isNamed,
    this.userName,
    this.photoUrl,
    required this.upvotes,
    required this.flagCount,
    required this.status,
    required this.aiStatus,
    this.aiCheckedAt,
    required this.createdAt,
    this.retractedAt,
    this.updatedAt,
  });

  // ── Convert TO Firestore map (when writing) ───────────────
  Map<String, dynamic> toMap() {
    return {
      'institutionId':    institutionId,
      'institutionName':  institutionName,
      'categoryId':       categoryId,
      'district':         district,
      'province':         province,
      'description':      description,
      'bribeAmount':      bribeAmount,
      'incidentDate':     incidentDate.toIso8601String().split('T')[0], // YYYY-MM-DD
      'lat':              lat,
      'lng':              lng,
      'userId':           userId,
      'isNamed':          isNamed,
      'userName':         userName,
      'photoUrl':         photoUrl,
      'upvotes':          upvotes,
      'flagCount':        flagCount,
      'status':           status.name,
      'aiStatus':         aiStatus.name,
      'aiCheckedAt':      aiCheckedAt != null
                            ? Timestamp.fromDate(aiCheckedAt!)
                            : null,
      'createdAt':        FieldValue.serverTimestamp(), // always use server time
      'retractedAt':      retractedAt != null
                            ? Timestamp.fromDate(retractedAt!)
                            : null,
      'updatedAt':        updatedAt != null
                            ? Timestamp.fromDate(updatedAt!)
                            : null,
    };
  }

  // ── Create FROM Firestore document (when reading) ─────────
  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      reportId:         doc.id,
      institutionId:    data['institutionId']   ?? '',
      institutionName:  data['institutionName'] ?? '',
      categoryId:       data['categoryId']      ?? 'other',
      district:         data['district']        ?? '',
      province:         data['province'],
      description:      data['description']     ?? '',
      bribeAmount:      data['bribeAmount'] != null
                          ? (data['bribeAmount'] as num).toDouble()
                          : null,
      incidentDate:     DateTime.parse(data['incidentDate']),
      lat:              data['lat'] != null
                          ? (data['lat'] as num).toDouble()
                          : null,
      lng:              data['lng'] != null
                          ? (data['lng'] as num).toDouble()
                          : null,
      userId:           data['userId']          ?? '',
      isNamed:          data['isNamed']         ?? false,
      userName:         data['userName'],
      photoUrl:         data['photoUrl'],
      upvotes:          data['upvotes']         ?? 0,
      flagCount:        data['flagCount']       ?? 0,
      status:           _parseStatus(data['status']),
      aiStatus:         _parseAiStatus(data['aiStatus']),
      aiCheckedAt:      data['aiCheckedAt'] != null
                          ? (data['aiCheckedAt'] as Timestamp).toDate()
                          : null,
      createdAt:        data['createdAt'] != null
                          ? (data['createdAt'] as Timestamp).toDate()
                          : DateTime.now(),
      retractedAt:      data['retractedAt'] != null
                          ? (data['retractedAt'] as Timestamp).toDate()
                          : null,
      updatedAt:        data['updatedAt'] != null
                          ? (data['updatedAt'] as Timestamp).toDate()
                          : null,
    );
  }

  // ── Parse status string to enum ───────────────────────────
  static ReportStatus _parseStatus(String? value) {
    switch (value) {
      case 'retracted': return ReportStatus.retracted;
      case 'flagged':   return ReportStatus.flagged;
      case 'removed':   return ReportStatus.removed;
      default:          return ReportStatus.active;
    }
  }

  // ── Parse AI status string to enum ────────────────────────
  static AiStatus _parseAiStatus(String? value) {
    switch (value) {
      case 'verified':   return AiStatus.verified;
      case 'flagged':    return AiStatus.flagged;
      default:           return AiStatus.unverified;
    }
  }

  // ── Computed helpers for UI ───────────────────────────────

  // Display name shown on feed card
  String get displayAuthor => isNamed && userName != null
      ? userName!
      : 'Anonymous Citizen';

  // AI badge text shown on feed card
  String get aiBadgeText {
    switch (aiStatus) {
      case AiStatus.verified:   return '🤖 AI Verified';
      case AiStatus.unverified: return '⚠️ Unverified';
      case AiStatus.flagged:    return '🚩 Flagged';
    }
  }

  // Short preview for feed card (first 100 chars)
  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }

  // Is this report visible on public feed?
  bool get isVisible => status == ReportStatus.active;

  // Bribe amount formatted in NPR
  String get formattedBribeAmount {
    if (bribeAmount == null) return 'Amount not specified';
    return 'Rs. ${bribeAmount!.toStringAsFixed(0)}';
  }

  // ── copyWith — for partial updates ────────────────────────
  ReportModel copyWith({
    int?          upvotes,
    int?          flagCount,
    ReportStatus? status,
    AiStatus?     aiStatus,
    DateTime?     aiCheckedAt,
    DateTime?     retractedAt,
    DateTime?     updatedAt,
    String?       photoUrl,
  }) {
    return ReportModel(
      reportId:        reportId,
      institutionId:   institutionId,
      institutionName: institutionName,
      categoryId:      categoryId,
      district:        district,
      province:        province,
      description:     description,
      bribeAmount:     bribeAmount,
      incidentDate:    incidentDate,
      lat:             lat,
      lng:             lng,
      userId:          userId,
      isNamed:         isNamed,
      userName:        userName,
      photoUrl:        photoUrl     ?? this.photoUrl,
      upvotes:         upvotes      ?? this.upvotes,
      flagCount:       flagCount    ?? this.flagCount,
      status:          status       ?? this.status,
      aiStatus:        aiStatus     ?? this.aiStatus,
      aiCheckedAt:     aiCheckedAt  ?? this.aiCheckedAt,
      createdAt:       createdAt,
      retractedAt:     retractedAt  ?? this.retractedAt,
      updatedAt:       updatedAt    ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ReportModel('
        'reportId: $reportId, '
        'institution: $institutionName, '
        'district: $district, '
        'isNamed: $isNamed, '
        'upvotes: $upvotes, '
        'status: ${status.name}, '
        'aiStatus: ${aiStatus.name}'
        ')';
  }
}
