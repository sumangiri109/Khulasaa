import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// FirestoreService
// Base helper — central place for all collection references.
// Every other service uses these references instead of typing
// 'reports', 'institutions' etc as raw strings everywhere.
// This avoids typos and makes renaming a collection painless.
// ============================================================

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection references — single source of truth ───────
  CollectionReference get users         => _db.collection('users');
  CollectionReference get categories    => _db.collection('categories');
  CollectionReference get institutions  => _db.collection('institutions');
  CollectionReference get reports       => _db.collection('reports');
  CollectionReference get upvoters      => _db.collection('upvoters');
  CollectionReference get flags         => _db.collection('flags');
  CollectionReference get hotspots      => _db.collection('hotspots');
  CollectionReference get notifications => _db.collection('notifications');
  CollectionReference get ciaaReviews   => _db.collection('ciaa_reviews');
  CollectionReference get moderators    => _db.collection('moderators');

  // ── Raw Firestore instance — for transactions/batches ─────
  FirebaseFirestore get instance => _db;

  // ── Run a transaction (used by upvote, ciaa review, etc) ──
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction tx) action,
  ) {
    return _db.runTransaction(action);
  }

  // ── Run a batch write (used for multi-document updates) ───
  WriteBatch batch() => _db.batch();

  // ── Server timestamp helper ───────────────────────────────
  FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  // ── Increment helper ───────────────────────────────────────
  FieldValue increment(num value) => FieldValue.increment(value);
}
