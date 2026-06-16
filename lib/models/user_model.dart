import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// UserModel
// Firestore collection: /users/{userId}
// IMPORTANT: Only named users have a document here.
// Anonymous users have NO document in this collection.
// userId = Firebase Auth anonymous UID
// ============================================================

class UserModel {
  final String userId;
  final String displayName;
  final bool identityDisclosed;
  final DateTime? disclosedAt;
  final int reportsCount;
  final int upvotesGiven;
  final String languagePreference; // 'en' or 'ne'
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.userId,
    required this.displayName,
    required this.identityDisclosed,
    this.disclosedAt,
    required this.reportsCount,
    required this.upvotesGiven,
    required this.languagePreference,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Convert TO Firestore map (when writing) ──────────────
  Map<String, dynamic> toMap() {
    return {
      'userId':             userId,
      'displayName':        displayName,
      'identityDisclosed':  identityDisclosed,
      'disclosedAt':        disclosedAt != null
                              ? Timestamp.fromDate(disclosedAt!)
                              : null,
      'reportsCount':       reportsCount,
      'upvotesGiven':       upvotesGiven,
      'languagePreference': languagePreference,
      'createdAt':          Timestamp.fromDate(createdAt),
      'updatedAt':          Timestamp.fromDate(updatedAt),
    };
  }

  // ── Create FROM Firestore document (when reading) ────────
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId:             doc.id,
      displayName:        data['displayName']        ?? '',
      identityDisclosed:  data['identityDisclosed']  ?? false,
      disclosedAt:        data['disclosedAt'] != null
                            ? (data['disclosedAt'] as Timestamp).toDate()
                            : null,
      reportsCount:       data['reportsCount']       ?? 0,
      upvotesGiven:       data['upvotesGiven']       ?? 0,
      languagePreference: data['languagePreference'] ?? 'en',
      createdAt:          (data['createdAt'] as Timestamp).toDate(),
      updatedAt:          (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // ── Create FROM Map (when reading from local cache) ──────
  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      userId:             id,
      displayName:        data['displayName']        ?? '',
      identityDisclosed:  data['identityDisclosed']  ?? false,
      disclosedAt:        data['disclosedAt'] != null
                            ? (data['disclosedAt'] as Timestamp).toDate()
                            : null,
      reportsCount:       data['reportsCount']       ?? 0,
      upvotesGiven:       data['upvotesGiven']       ?? 0,
      languagePreference: data['languagePreference'] ?? 'en',
      createdAt:          (data['createdAt'] as Timestamp).toDate(),
      updatedAt:          (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // ── copyWith — for updating specific fields only ─────────
  UserModel copyWith({
    String?   displayName,
    bool?     identityDisclosed,
    DateTime? disclosedAt,
    int?      reportsCount,
    int?      upvotesGiven,
    String?   languagePreference,
    DateTime? updatedAt,
  }) {
    return UserModel(
      userId:             userId,
      displayName:        displayName        ?? this.displayName,
      identityDisclosed:  identityDisclosed  ?? this.identityDisclosed,
      disclosedAt:        disclosedAt        ?? this.disclosedAt,
      reportsCount:       reportsCount       ?? this.reportsCount,
      upvotesGiven:       upvotesGiven       ?? this.upvotesGiven,
      languagePreference: languagePreference ?? this.languagePreference,
      createdAt:          createdAt,
      updatedAt:          updatedAt          ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel('
        'userId: $userId, '
        'displayName: $displayName, '
        'identityDisclosed: $identityDisclosed, '
        'reportsCount: $reportsCount'
        ')';
  }
}
