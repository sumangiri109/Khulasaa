import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// NotificationModel
// Firestore collection: /notifications/{notificationId}
// Created by Python nightly scheduler
// General Nepal-wide scope only (as decided)
// ============================================================

enum NotificationType {
  spikeAlert,  // AI detected corruption surge
  general,      // Manual announcement
  system,       // App update or maintenance
}

enum RecipientScope {
  allNepal,    // Everyone — default for now
  district,     // Future: district-specific
  institution,  // Future: institution-specific
}

class NotificationModel {
  final String notificationId;
  final String title;
  final String body;
  final NotificationType type;
  final String? institutionId;   // Which institution triggered — null for general
  final String? hotspotId;       // Which hotspot triggered — null for general
  final DateTime sentAt;
  final RecipientScope recipientScope;

  const NotificationModel({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.type,
    this.institutionId,
    this.hotspotId,
    required this.sentAt,
    required this.recipientScope,
  });

  // ── Convert TO Firestore map ──────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'title':           title,
      'body':            body,
      'type':            type.name,
      'institutionId':   institutionId,
      'hotspotId':       hotspotId,
      'sentAt':          Timestamp.fromDate(sentAt),
      'recipientScope':  recipientScope.name,
    };
  }

  // ── Create FROM Firestore document ────────────────────────
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId:  doc.id,
      title:           data['title']           ?? '',
      body:            data['body']            ?? '',
      type:            _parseType(data['type']),
      institutionId:   data['institutionId'],
      hotspotId:       data['hotspotId'],
      sentAt:          data['sentAt'] != null
                         ? (data['sentAt'] as Timestamp).toDate()
                         : DateTime.now(),
      recipientScope:  _parseScope(data['recipientScope']),
    );
  }

  static NotificationType _parseType(String? value) {
    switch (value) {
      case 'general': return NotificationType.general;
      case 'system':  return NotificationType.system;
      default:        return NotificationType.spikeAlert;
    }
  }

  static RecipientScope _parseScope(String? value) {
    switch (value) {
      case 'district':    return RecipientScope.district;
      case 'institution': return RecipientScope.institution;
      default:            return RecipientScope.allNepal;
    }
  }

  @override
  String toString() =>
      'NotificationModel(id: $notificationId, title: $title, type: ${type.name})';
}
