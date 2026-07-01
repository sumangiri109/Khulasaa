import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// ReportModel — RESTRUCTURED v2
// Firestore collection: /reports/{reportId}
//
// KEY CHANGES FROM v1:
// 1. Added ReportType enum (infrastructure/institutional/personal)
// 2. Added CIAA-specific statuses to ReportStatus
// 3. Added speechInput field (was report spoken or typed?)
// 4. Added aiExtracted fields (auto-filled by AI from text)
// 5. Added corruptionType field (what kind of corruption)
// 6. Personal accusations route to CIAA BEFORE going public
// ============================================================

// ── Report Type — determines routing ─────────────────────
// This is the most critical field in the entire model.
// AI auto-detects this from the report text.
// Infrastructure → publish immediately (no person accused)
// Institutional  → publish after AI check (office named, not individual)
// Personal       → goes to CIAA dashboard FIRST, never public until verified
enum ReportType {
  infrastructure, // e.g. "Contractor bribed to get road contract"
  institutional, // e.g. "Land office demands Rs.5000 for every application"
  personal, // e.g. "Officer Ram Bahadur demanded Rs.5000" ← CIAA routes here
}

// ── Report Status — full lifecycle ───────────────────────
enum ReportStatus {
  // Normal flow statuses
  active, // Live on public feed
  retracted, // Author retracted — hidden from feed, stays in DB
  flagged, // 5+ community flags — auto-hidden, pending review
  // CIAA flow statuses (personal accusations only)
  pendingCiaa, // Submitted, waiting for CIAA to review — NOT public
  ciaaVerified, // CIAA confirmed guilty — NOW public with verified badge
  ciaaRejected, // CIAA found not guilty — stays private, reporter notified
  // Admin
  removed, // Admin removed permanently
}

// ── AI Status — confidence of AI analysis ────────────────
enum AiStatus {
  verified, // Passed all checks + pattern match found
  unverified, // Passed basic checks but no strong pattern yet
  flagged, // AI detected suspicious content
}

// ── Corruption Type — what kind of corruption ────────────
enum CorruptionType {
  bribery, // Direct payment demanded
  embezzlement, // Public funds misused
  abuseOfAuthority, // Power misused without payment
  fakeAppointment, // Job/promotion for money
  extortion, // Threatened unless paid
  fraud, // Fake documents or services
  other,
}

// ── AI Extracted Data — auto-filled from speech/text ─────
// When user speaks or types, AI extracts these automatically
// User just reviews and confirms — doesn't fill manually
class AiExtractedData {
  final String? detectedDistrict; // e.g. "Kavre"
  final String? detectedCategory; // e.g. "land_revenue"
  final String? detectedOfficeName; // e.g. "Kavre Land Office"
  final double? detectedBribeAmount; // e.g. 3000.0
  final DateTime? detectedDate; // e.g. last Tuesday → actual date
  final ReportType detectedType; // infrastructure/institutional/personal
  final CorruptionType detectedCorruptionType;
  final bool containsPersonName; // Did AI find a person's name?
  final String? detectedPersonName; // The name found, if any
  final double confidenceScore; // 0.0 to 1.0 — how confident AI is

  const AiExtractedData({
    this.detectedDistrict,
    this.detectedCategory,
    this.detectedOfficeName,
    this.detectedBribeAmount,
    this.detectedDate,
    required this.detectedType,
    required this.detectedCorruptionType,
    required this.containsPersonName,
    this.detectedPersonName,
    required this.confidenceScore,
  });

  Map<String, dynamic> toMap() => {
    'detectedDistrict': detectedDistrict,
    'detectedCategory': detectedCategory,
    'detectedOfficeName': detectedOfficeName,
    'detectedBribeAmount': detectedBribeAmount,
    'detectedDate': detectedDate?.toIso8601String(),
    'detectedType': detectedType.name,
    'detectedCorruptionType': detectedCorruptionType.name,
    'containsPersonName': containsPersonName,
    'detectedPersonName': detectedPersonName,
    'confidenceScore': confidenceScore,
  };

  factory AiExtractedData.fromMap(Map<String, dynamic> data) {
    return AiExtractedData(
      detectedDistrict: data['detectedDistrict'],
      detectedCategory: data['detectedCategory'],
      detectedOfficeName: data['detectedOfficeName'],
      detectedBribeAmount: data['detectedBribeAmount'] != null
          ? (data['detectedBribeAmount'] as num).toDouble()
          : null,
      detectedDate: data['detectedDate'] != null
          ? DateTime.parse(data['detectedDate'])
          : null,
      detectedType: _parseType(data['detectedType']),
      detectedCorruptionType: _parseCorruptionType(
        data['detectedCorruptionType'],
      ),
      containsPersonName: data['containsPersonName'] ?? false,
      detectedPersonName: data['detectedPersonName'],
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static ReportType _parseType(String? v) {
    switch (v) {
      case 'institutional':
        return ReportType.institutional;
      case 'personal':
        return ReportType.personal;
      default:
        return ReportType.infrastructure;
    }
  }

  static CorruptionType _parseCorruptionType(String? v) {
    switch (v) {
      case 'embezzlement':
        return CorruptionType.embezzlement;
      case 'abuseOfAuthority':
        return CorruptionType.abuseOfAuthority;
      case 'fakeAppointment':
        return CorruptionType.fakeAppointment;
      case 'extortion':
        return CorruptionType.extortion;
      case 'fraud':
        return CorruptionType.fraud;
      default:
        return CorruptionType.bribery;
    }
  }
}

// ── Main ReportModel ──────────────────────────────────────
class ReportModel {
  final String reportId;

  // ── Core report data ──────────────────────────────────
  final String institutionId;
  final String institutionName; // Snapshot at time of report
  final String categoryId; // Snapshot at time of report
  final String district;
  final String? province;
  final String description; // Min 50 chars — typed or transcribed from speech
  final double? bribeAmount; // NPR — null if not provided
  final DateTime incidentDate;
  final double? lat;
  final double? lng;

  // ── Report classification ─────────────────────────────
  final ReportType reportType; // infrastructure/institutional/personal
  final CorruptionType corruptionType; // what kind of corruption

  // ── Input method ─────────────────────────────────────
  final bool wasSpeechInput; // true = user spoke, false = user typed
  final String? originalSpeechTranscript; // raw transcript before AI cleanup

  // ── AI extraction results ─────────────────────────────
  final AiExtractedData? aiExtracted; // what AI auto-detected from text

  // ── Identity ──────────────────────────────────────────
  final String userId; // Firebase anonymous UID
  final bool isNamed; // Did user toggle identity ON for this report?
  final String? userName; // Snapshot of name — null if anonymous

  // ── Evidence ─────────────────────────────────────────
  final String? photoUrl; // Firebase Storage URL

  // ── Community engagement ──────────────────────────────
  final int upvotes;
  final int flagCount;

  // ── Status & AI ──────────────────────────────────────
  final ReportStatus status;
  final AiStatus aiStatus;
  final DateTime? aiCheckedAt;

  // ── CIAA specific fields ──────────────────────────────
  // Only populated for personal accusation reports
  final String? ciaaReviewId; // FK → ciaa_reviews collection
  final DateTime? ciaaSubmittedAt; // When sent to CIAA dashboard
  final DateTime? ciaaResolvedAt; // When CIAA marked guilty/not guilty
  final String?
  ciaaReviewerNote; // CIAA reviewer's public note (shown if verified)

  // ── Timestamps ───────────────────────────────────────
  final DateTime createdAt;
  final DateTime? retractedAt;
  final DateTime? updatedAt;

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
    required this.reportType,
    required this.corruptionType,
    required this.wasSpeechInput,
    this.originalSpeechTranscript,
    this.aiExtracted,
    required this.userId,
    required this.isNamed,
    this.userName,
    this.photoUrl,
    required this.upvotes,
    required this.flagCount,
    required this.status,
    required this.aiStatus,
    this.aiCheckedAt,
    this.ciaaReviewId,
    this.ciaaSubmittedAt,
    this.ciaaResolvedAt,
    this.ciaaReviewerNote,
    required this.createdAt,
    this.retractedAt,
    this.updatedAt,
  });

  // ── Convert TO Firestore map ──────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'institutionId': institutionId,
      'institutionName': institutionName,
      'categoryId': categoryId,
      'district': district,
      'province': province,
      'description': description,
      'bribeAmount': bribeAmount,
      'incidentDate': incidentDate.toIso8601String().split('T')[0],
      'lat': lat,
      'lng': lng,
      'reportType': reportType.name,
      'corruptionType': corruptionType.name,
      'wasSpeechInput': wasSpeechInput,
      'originalSpeechTranscript': originalSpeechTranscript,
      'aiExtracted': aiExtracted?.toMap(),
      'userId': userId,
      'isNamed': isNamed,
      'userName': userName,
      'photoUrl': photoUrl,
      'upvotes': upvotes,
      'flagCount': flagCount,
      'status': status.name,
      'aiStatus': aiStatus.name,
      'aiCheckedAt': aiCheckedAt != null
          ? Timestamp.fromDate(aiCheckedAt!)
          : null,
      'ciaaReviewId': ciaaReviewId,
      'ciaaSubmittedAt': ciaaSubmittedAt != null
          ? Timestamp.fromDate(ciaaSubmittedAt!)
          : null,
      'ciaaResolvedAt': ciaaResolvedAt != null
          ? Timestamp.fromDate(ciaaResolvedAt!)
          : null,
      'ciaaReviewerNote': ciaaReviewerNote,
      'createdAt': FieldValue.serverTimestamp(),
      'retractedAt': retractedAt != null
          ? Timestamp.fromDate(retractedAt!)
          : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // ── Create FROM Firestore document ────────────────────
  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReportModel(
      reportId: doc.id,
      institutionId: d['institutionId'] ?? '',
      institutionName: d['institutionName'] ?? '',
      categoryId: d['categoryId'] ?? 'other',
      district: d['district'] ?? '',
      province: d['province'],
      description: d['description'] ?? '',
      bribeAmount: d['bribeAmount'] != null
          ? (d['bribeAmount'] as num).toDouble()
          : null,
      incidentDate: DateTime.parse(d['incidentDate']),
      lat: d['lat'] != null ? (d['lat'] as num).toDouble() : null,
      lng: d['lng'] != null ? (d['lng'] as num).toDouble() : null,
      reportType: _parseReportType(d['reportType']),
      corruptionType: _parseCorruptionType(d['corruptionType']),
      wasSpeechInput: d['wasSpeechInput'] ?? false,
      originalSpeechTranscript: d['originalSpeechTranscript'],
      aiExtracted: d['aiExtracted'] != null
          ? AiExtractedData.fromMap(Map<String, dynamic>.from(d['aiExtracted']))
          : null,
      userId: d['userId'] ?? '',
      isNamed: d['isNamed'] ?? false,
      userName: d['userName'],
      photoUrl: d['photoUrl'],
      upvotes: d['upvotes'] ?? 0,
      flagCount: d['flagCount'] ?? 0,
      status: _parseStatus(d['status']),
      aiStatus: _parseAiStatus(d['aiStatus']),
      aiCheckedAt: d['aiCheckedAt'] != null
          ? (d['aiCheckedAt'] as Timestamp).toDate()
          : null,
      ciaaReviewId: d['ciaaReviewId'],
      ciaaSubmittedAt: d['ciaaSubmittedAt'] != null
          ? (d['ciaaSubmittedAt'] as Timestamp).toDate()
          : null,
      ciaaResolvedAt: d['ciaaResolvedAt'] != null
          ? (d['ciaaResolvedAt'] as Timestamp).toDate()
          : null,
      ciaaReviewerNote: d['ciaaReviewerNote'],
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      retractedAt: d['retractedAt'] != null
          ? (d['retractedAt'] as Timestamp).toDate()
          : null,
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // ── Enum parsers ──────────────────────────────────────
  static ReportType _parseReportType(String? v) {
    switch (v) {
      case 'institutional':
        return ReportType.institutional;
      case 'personal':
        return ReportType.personal;
      default:
        return ReportType.infrastructure;
    }
  }

  static CorruptionType _parseCorruptionType(String? v) {
    switch (v) {
      case 'embezzlement':
        return CorruptionType.embezzlement;
      case 'abuseOfAuthority':
        return CorruptionType.abuseOfAuthority;
      case 'fakeAppointment':
        return CorruptionType.fakeAppointment;
      case 'extortion':
        return CorruptionType.extortion;
      case 'fraud':
        return CorruptionType.fraud;
      default:
        return CorruptionType.bribery;
    }
  }

  static ReportStatus _parseStatus(String? v) {
    switch (v) {
      case 'retracted':
        return ReportStatus.retracted;
      case 'flagged':
        return ReportStatus.flagged;
      case 'pendingCiaa':
        return ReportStatus.pendingCiaa;
      case 'ciaaVerified':
        return ReportStatus.ciaaVerified;
      case 'ciaaRejected':
        return ReportStatus.ciaaRejected;
      case 'removed':
        return ReportStatus.removed;
      default:
        return ReportStatus.active;
    }
  }

  static AiStatus _parseAiStatus(String? v) {
    switch (v) {
      case 'verified':
        return AiStatus.verified;
      case 'flagged':
        return AiStatus.flagged;
      default:
        return AiStatus.unverified;
    }
  }

  // ── Computed helpers for UI ───────────────────────────

  // Is report visible on public feed?
  bool get isPublic =>
      status == ReportStatus.active || status == ReportStatus.ciaaVerified;

  // Is report waiting for CIAA?
  bool get isPendingCiaa => status == ReportStatus.pendingCiaa;

  // Does this report need CIAA routing?
  bool get requiresCiaaReview => reportType == ReportType.personal;

  // Display author on feed card
  String get displayAuthor =>
      isNamed && userName != null ? userName! : 'Anonymous Citizen';

  // AI badge text
  String get aiBadgeText {
    switch (aiStatus) {
      case AiStatus.verified:
        return '🤖 AI Verified';
      case AiStatus.unverified:
        return '⚠️ Unverified';
      case AiStatus.flagged:
        return '🚩 Flagged';
    }
  }

  // CIAA badge — shown on ciaaVerified reports
  String get ciaaBadgeText {
    if (status == ReportStatus.ciaaVerified) return '✅ CIAA Verified';
    if (status == ReportStatus.pendingCiaa) return '🔍 Under CIAA Review';
    return '';
  }

  // Short preview for feed card
  String get shortDescription => description.length <= 100
      ? description
      : '${description.substring(0, 100)}...';

  // Formatted bribe amount
  String get formattedBribeAmount => bribeAmount != null
      ? 'Rs. ${bribeAmount!.toStringAsFixed(0)}'
      : 'Amount not specified';

  // Report type label for UI
  String get reportTypeLabel {
    switch (reportType) {
      case ReportType.infrastructure:
        return 'Infrastructure Corruption';
      case ReportType.institutional:
        return 'Institutional Corruption';
      case ReportType.personal:
        return 'Personal Accusation';
    }
  }

  // ── copyWith ─────────────────────────────────────────
  ReportModel copyWith({
    int? upvotes,
    int? flagCount,
    ReportStatus? status,
    AiStatus? aiStatus,
    DateTime? aiCheckedAt,
    String? ciaaReviewId,
    DateTime? ciaaSubmittedAt,
    DateTime? ciaaResolvedAt,
    String? ciaaReviewerNote,
    DateTime? retractedAt,
    DateTime? updatedAt,
    String? photoUrl,
  }) {
    return ReportModel(
      reportId: reportId,
      institutionId: institutionId,
      institutionName: institutionName,
      categoryId: categoryId,
      district: district,
      province: province,
      description: description,
      bribeAmount: bribeAmount,
      incidentDate: incidentDate,
      lat: lat,
      lng: lng,
      reportType: reportType,
      corruptionType: corruptionType,
      wasSpeechInput: wasSpeechInput,
      originalSpeechTranscript: originalSpeechTranscript,
      aiExtracted: aiExtracted,
      userId: userId,
      isNamed: isNamed,
      userName: userName,
      photoUrl: photoUrl ?? this.photoUrl,
      upvotes: upvotes ?? this.upvotes,
      flagCount: flagCount ?? this.flagCount,
      status: status ?? this.status,
      aiStatus: aiStatus ?? this.aiStatus,
      aiCheckedAt: aiCheckedAt ?? this.aiCheckedAt,
      ciaaReviewId: ciaaReviewId ?? this.ciaaReviewId,
      ciaaSubmittedAt: ciaaSubmittedAt ?? this.ciaaSubmittedAt,
      ciaaResolvedAt: ciaaResolvedAt ?? this.ciaaResolvedAt,
      ciaaReviewerNote: ciaaReviewerNote ?? this.ciaaReviewerNote,
      createdAt: createdAt,
      retractedAt: retractedAt ?? this.retractedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ReportModel('
      'id: $reportId, '
      'type: ${reportType.name}, '
      'status: ${status.name}, '
      'institution: $institutionName'
      ')';
}
