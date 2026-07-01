import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

// ============================================================
// AuthService
// Handles the entire identity system designed for Khulasaa:
//
// 1. Every user starts ANONYMOUS automatically on app open
// 2. User can OPTIONALLY disclose identity in Settings
//    → creates a document in /users/{uid}
// 3. Anonymous users have NO /users document — by design
// 4. Per-report toggle uses this service to check disclosure
//    status before allowing the "show identity" toggle
// ============================================================

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  // ── Current Firebase user (always exists after init) ──────
  User? get currentUser => _auth.currentUser;

  // ── Current user's UID — used everywhere as userId ─────────
  String? get currentUserId => _auth.currentUser?.uid;

  // ── Is current session anonymous? ──────────────────────────
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  // ── Auth state stream — listen to login state changes ──────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ════════════════════════════════════════════════════════
  // STEP 1 — Called once when app first opens (in main.dart
  // or a splash screen). Creates anonymous session if none
  // exists yet. Safe to call every app launch — Firebase
  // reuses existing anonymous session automatically.
  // ════════════════════════════════════════════════════════
  Future<User> ensureSignedIn() async {
    if (_auth.currentUser != null) {
      return _auth.currentUser!;
    }
    final credential = await _auth.signInAnonymously();
    if (credential.user == null) {
      throw Exception('Failed to create anonymous session');
    }
    return credential.user!;
  }

  // ════════════════════════════════════════════════════════
  // STEP 2 — Check if current user has disclosed identity
  // Used by Settings screen and the per-report toggle to
  // decide: show toggle as active, or redirect to Settings?
  // ════════════════════════════════════════════════════════
  Future<UserModel?> getCurrentUserProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final doc = await _firestore.users.doc(uid).get();
    if (!doc.exists) {
      return null; // No profile = never disclosed identity
    }
    return UserModel.fromFirestore(doc);
  }

  // Quick boolean check — used in report Step 3 toggle logic
  Future<bool> hasDisclosedIdentity() async {
    final profile = await getCurrentUserProfile();
    return profile?.identityDisclosed ?? false;
  }

  // ════════════════════════════════════════════════════════
  // STEP 3 — Disclose identity (called from Settings screen)
  // This is the ONE-TIME setup. After this, the per-report
  // toggle becomes available for every future report.
  // ════════════════════════════════════════════════════════
  Future<UserModel> discloseIdentity({
    required String displayName,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw Exception('No active session — call ensureSignedIn() first');
    }

    if (displayName.trim().isEmpty) {
      throw Exception('Display name cannot be empty');
    }

    final now = DateTime.now();
    final existingDoc = await _firestore.users.doc(uid).get();

    if (existingDoc.exists) {
      // Already has a profile — just update the name and flag
      await _firestore.users.doc(uid).update({
        'displayName':       displayName.trim(),
        'identityDisclosed': true,
        'disclosedAt':       Timestamp.fromDate(now),
        'updatedAt':         Timestamp.fromDate(now),
      });
    } else {
      // First time disclosing — create the user profile
      final newUser = UserModel(
        userId:             uid,
        displayName:        displayName.trim(),
        identityDisclosed:  true,
        disclosedAt:        now,
        reportsCount:       0,
        upvotesGiven:       0,
        languagePreference: 'en',
        createdAt:          now,
        updatedAt:          now,
      );
      await _firestore.users.doc(uid).set(newUser.toMap());
    }

    return (await getCurrentUserProfile())!;
  }

  // ════════════════════════════════════════════════════════
  // STEP 4 — Withdraw identity disclosure (optional feature)
  // Turns OFF identityDisclosed. Past reports keep their
  // name snapshot (by design — see ReportModel.userName).
  // Future reports will default to anonymous.
  // ════════════════════════════════════════════════════════
  Future<void> withdrawIdentityDisclosure() async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.users.doc(uid).update({
      'identityDisclosed': false,
      'updatedAt':         Timestamp.fromDate(DateTime.now()),
    });
  }

  // ════════════════════════════════════════════════════════
  // Update language preference (Settings screen)
  // ════════════════════════════════════════════════════════
  Future<void> updateLanguagePreference(String languageCode) async {
    final uid = currentUserId;
    if (uid == null) return;

    final doc = await _firestore.users.doc(uid).get();
    if (!doc.exists) return; // Anonymous users have no profile to update

    await _firestore.users.doc(uid).update({
      'languagePreference': languageCode,
      'updatedAt':           Timestamp.fromDate(DateTime.now()),
    });
  }

  // ════════════════════════════════════════════════════════
  // CIAA MODERATOR LOGIN — separate from citizen auth
  // CIAA officers use email/password, NOT anonymous auth
  // ════════════════════════════════════════════════════════
  Future<UserCredential> moderatorSignIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ════════════════════════════════════════════════════════
  // Increment user's reportsCount — called by ReportService
  // after successful submission (named reports only, since
  // anonymous users have no profile document to update)
  // ════════════════════════════════════════════════════════
  Future<void> incrementReportsCount(String uid) async {
    final doc = await _firestore.users.doc(uid).get();
    if (!doc.exists) return; // anonymous — nothing to increment

    await _firestore.users.doc(uid).update({
      'reportsCount': _firestore.increment(1),
      'updatedAt':    Timestamp.fromDate(DateTime.now()),
    });
  }

  // Increment user's upvotesGiven — called by UpvoteService
  Future<void> incrementUpvotesGiven(String uid) async {
    final doc = await _firestore.users.doc(uid).get();
    if (!doc.exists) return; // anonymous — nothing to increment

    await _firestore.users.doc(uid).update({
      'upvotesGiven': _firestore.increment(1),
      'updatedAt':    Timestamp.fromDate(DateTime.now()),
    });
  }
}
