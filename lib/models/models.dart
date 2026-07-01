// ============================================================
// KHULASAA v2 — All Models Export
// Import this single file anywhere in the project:
// import 'package:khulasaa/models/models.dart';
//
// CHANGES FROM v1:
// + ciaa_review_model.dart  (NEW — CIAA investigation workflow)
// + moderator_model.dart    (NEW — CIAA dashboard users)
// ~ report_model.dart       (UPDATED — report types, routing, CIAA fields)
// ~ institution_model.dart  (UPDATED — corruption type breakdown)
// = everything else unchanged
// ============================================================

// Core models
export 'user_model.dart';
export 'category_model.dart';
export 'institution_model.dart';
export 'report_model.dart';

// Community models
export 'upvoter_model.dart';
export 'flag_model.dart';

// NEW — CIAA workflow models
export 'ciaa_review_model.dart';
export 'moderator_model.dart';

// AI & map models
export 'hotspot_model.dart';
export 'notification_model.dart';
