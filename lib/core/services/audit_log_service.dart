import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuditLogService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Records any mobile app activity into Firestore `audit_logs`
  /// with accurate user identity and `platform: 'mobile_app'`.
  static Future<void> log({
    required String action,
    required String resource,
    Map<String, dynamic>? details,
    String? userIdOverride,
    String? userEmailOverride,
    String? userNameOverride,
    String? userRoleOverride,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = userIdOverride ?? currentUser?.uid ?? 'anonymous';
      String email = userEmailOverride ?? currentUser?.email ?? '';
      String name = userNameOverride ?? currentUser?.displayName ?? '';
      String role = userRoleOverride ?? 'OBSERVER';
      String phone = currentUser?.phoneNumber ?? '';

      if (uid != 'anonymous' && (name.isEmpty || email.isEmpty)) {
        try {
          final doc = await _db.collection('users').doc(uid).get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            name = (data['name'] ??
                    '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim())
                .toString()
                .trim();
            if (name.isEmpty) name = data['fullName']?.toString() ?? '';
            email = (data['email'] ?? email).toString();
            role = (data['role'] ?? role).toString().toUpperCase();
            phone = (data['phone'] ?? data['phoneNumber'] ?? phone).toString();
          }
        } catch (_) {}
      }

      if (name.isEmpty && email.isNotEmpty) {
        name = email.split('@').first;
      }

      final docRef = _db.collection('audit_logs').doc();
      await docRef.set({
        'id': docRef.id,
        '_docId': docRef.id,
        'action': action.toUpperCase(),
        'resource': resource,
        'userId': uid,
        'userName': name.isNotEmpty ? name : 'Mobile Observer',
        'userEmail': email,
        'userRole': role.toUpperCase(),
        'phone': phone,
        'method': 'mobile_app',
        'platform': 'mobile_app',
        'userAgent': 'VoteGuard Flutter Mobile (${defaultTargetPlatform.name})',
        'details': {
          'platform': 'mobile_app',
          'os': defaultTargetPlatform.name,
          ...?details,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AuditLogService notice: $e');
    }
  }
}
