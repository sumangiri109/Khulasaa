import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// ModeratorModel — NEW in v2
// Firestore collection: /moderators/{moderatorId}
//
// CIAA officials who have access to the moderator dashboard.
// These are NOT regular citizens — they are verified CIAA staff.
// Created manually by Khulasaa admin (your supervisor/team).
// They log in with email/password (NOT anonymous auth).
// ============================================================

enum ModeratorRole {
  ciaaOfficer, // Regular CIAA investigator
  ciaaAdmin, // Senior CIAA — can assign reviews to officers
  khulasaaAdmin, // Your team — full system access
}

class ModeratorModel {
  final String moderatorId; // Firebase Auth UID (email/password account)
  final String name; // Full name of CIAA officer
  final String email; // Official CIAA email
  final String? designation; // e.g. "Senior Investigation Officer"
  final ModeratorRole role;
  final bool isActive; // Can be deactivated without deleting account
  final int totalReviewed; // How many reviews this moderator has handled
  final int totalGuilty; // How many marked guilty
  final int totalNotGuilty; // How many cleared
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const ModeratorModel({
    required this.moderatorId,
    required this.name,
    required this.email,
    this.designation,
    required this.role,
    required this.isActive,
    required this.totalReviewed,
    required this.totalGuilty,
    required this.totalNotGuilty,
    required this.createdAt,
    this.lastLoginAt,
  });

  // ── Convert TO Firestore map ──────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'designation': designation,
      'role': role.name,
      'isActive': isActive,
      'totalReviewed': totalReviewed,
      'totalGuilty': totalGuilty,
      'totalNotGuilty': totalNotGuilty,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
    };
  }

  // ── Create FROM Firestore document ────────────────────
  factory ModeratorModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ModeratorModel(
      moderatorId: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      designation: d['designation'],
      role: _parseRole(d['role']),
      isActive: d['isActive'] ?? true,
      totalReviewed: d['totalReviewed'] ?? 0,
      totalGuilty: d['totalGuilty'] ?? 0,
      totalNotGuilty: d['totalNotGuilty'] ?? 0,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      lastLoginAt: d['lastLoginAt'] != null
          ? (d['lastLoginAt'] as Timestamp).toDate()
          : null,
    );
  }

  static ModeratorRole _parseRole(String? v) {
    switch (v) {
      case 'ciaaAdmin':
        return ModeratorRole.ciaaAdmin;
      case 'khulasaaAdmin':
        return ModeratorRole.khulasaaAdmin;
      default:
        return ModeratorRole.ciaaOfficer;
    }
  }

  // ── Computed helpers ──────────────────────────────────
  String get roleLabel {
    switch (role) {
      case ModeratorRole.ciaaOfficer:
        return 'CIAA Officer';
      case ModeratorRole.ciaaAdmin:
        return 'CIAA Administrator';
      case ModeratorRole.khulasaaAdmin:
        return 'Khulasaa Administrator';
    }
  }

  double get guiltRate =>
      totalReviewed > 0 ? (totalGuilty / totalReviewed) * 100 : 0.0;

  ModeratorModel copyWith({
    bool? isActive,
    int? totalReviewed,
    int? totalGuilty,
    int? totalNotGuilty,
    DateTime? lastLoginAt,
  }) {
    return ModeratorModel(
      moderatorId: moderatorId,
      name: name,
      email: email,
      designation: designation,
      role: role,
      isActive: isActive ?? this.isActive,
      totalReviewed: totalReviewed ?? this.totalReviewed,
      totalGuilty: totalGuilty ?? this.totalGuilty,
      totalNotGuilty: totalNotGuilty ?? this.totalNotGuilty,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  String toString() =>
      'ModeratorModel('
      'id: $moderatorId, '
      'name: $name, '
      'role: ${role.name}'
      ')';
}
