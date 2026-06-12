import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FirebaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Endpoint connecting to FastAPI AI Pipeline
  final String _backendUrl = "http://localhost:8000/api";

  /// Handles media uploads securely to Firebase Storage
  Future<String?> uploadEvidence(String reportId, String fileName, Uint8List fileBytes) async {
    try {
      Reference ref = _storage.ref().child('evidence/$reportId/$fileName');
      UploadTask uploadTask = ref.putData(fileBytes);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Firebase Storage Upload Error: $e");
      return null;
    }
  }

  /// Submits the corruption report.
  /// First, it hits the FastAPI TF-IDF Spam Filter.
  /// If validated, it records the report to Firestore.
  Future<Map<String, dynamic>> submitReport({
    required String institution,
    required String district,
    required String description,
    required double bribeAmount,
    required double latitude,
    required double longitude,
    String? evidenceUrl,
  }) async {
    try {
      // 1. Submit to FastAPI AI Spam check first
      final response = await http.post(
        Uri.parse("$_backendUrl/reports/submit"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "institution": institution,
          "district": district,
          "description": description,
          "bribeAmount": bribeAmount,
          "evidenceUrl": evidenceUrl ?? "",
          "lat": latitude,
          "lng": longitude,
          "isAnonymous": true
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // 2. Synchronize / write to Cloud Firestore for local clients
        if (data["success"] == true && data["status"] == "validated") {
          await _firestore.collection('reports').doc(data["id"]).set({
            "id": data["id"],
            "institution": institution,
            "district": district,
            "description": description,
            "bribeAmount": bribeAmount,
            "evidenceUrl": evidenceUrl ?? "",
            "lat": latitude,
            "lng": longitude,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "validated",
            "upvotes": 0,
            "confidence": data["confidence"]
          });
        }
        return data;
      } else {
        return {
          "success": false,
          "message": "AI Verification Server returned error: ${response.statusCode}"
        };
      }
    } catch (e) {
      debugPrint("Report submission pipeline failed: $e");
      return {
        "success": false,
        "message": "Failed to connect to machine learning verification pipeline."
      };
    }
  }

  /// Stream verified reports from Cloud Firestore
  Stream<QuerySnapshot> streamVerifiedReports() {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: 'validated')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Casts community upvote validating corruption disclosure
  Future<bool> upvoteReport(String reportId) async {
    try {
      // Trigger FastAPI upvoting and confidence scoring update
      final response = await http.post(Uri.parse("$_backendUrl/reports/$reportId/upvote"));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Update local Firestore count
        await _firestore.collection('reports').doc(reportId).update({
          "upvotes": FieldValue.increment(1),
          "confidence": data["confidence"]
        });
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Upvoting routine failed: $e");
      return false;
    }
  }

  /// Retrieve scorecards from FastAPI backend
  Future<List<Map<String, dynamic>>> fetchInstitutionalScorecards() async {
    try {
      final response = await http.get(Uri.parse("$_backendUrl/scorecards"));
      if (response.statusCode == 200) {
        List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Could not fetch scorecards from API: $e");
      return [];
    }
  }
}
