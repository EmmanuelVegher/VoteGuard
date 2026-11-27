import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuditLogService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? _cachedIp;
  static String? _cachedIsp;

  static String _inferIspFromIp(String ip, [String? explicitIsp]) {
    final raw = ip.trim().toLowerCase();
    if (raw.startsWith('2c0f:f5c0:') ||
        raw.startsWith('102.88.') ||
        raw.startsWith('102.89.') ||
        raw.startsWith('102.90.') ||
        raw.startsWith('102.91.') ||
        raw.startsWith('102.92.') ||
        raw.startsWith('102.93.') ||
        raw.startsWith('197.210.') ||
        raw.startsWith('41.206.') ||
        raw.startsWith('41.220.')) {
      return 'MTN Nigeria';
    }
    if (raw.startsWith('2c0f:2280:') ||
        raw.startsWith('2c0f:2a80:') ||
        raw.startsWith('105.112.') ||
        raw.startsWith('105.113.') ||
        raw.startsWith('105.114.') ||
        raw.startsWith('105.115.') ||
        raw.startsWith('105.116.') ||
        raw.startsWith('105.117.') ||
        raw.startsWith('105.118.') ||
        raw.startsWith('105.119.') ||
        raw.startsWith('105.120.') ||
        raw.startsWith('105.127.') ||
        raw.startsWith('197.255.') ||
        raw.startsWith('154.160.')) {
      return 'Airtel Nigeria';
    }
    if (raw.startsWith('2c0f:f888:') ||
        raw.startsWith('197.211.') ||
        raw.startsWith('129.205.') ||
        raw.startsWith('41.203.') ||
        raw.startsWith('154.66.')) {
      return 'Globacom (Glo)';
    }
    if (raw.startsWith('41.190.') ||
        raw.startsWith('154.113.') ||
        raw.startsWith('196.220.')) {
      return '9mobile (EMTS)';
    }
    if (raw.startsWith('129.222.') ||
        raw.startsWith('143.105.') ||
        raw.startsWith('135.129.') ||
        raw.startsWith('98.97.') ||
        raw.startsWith('149.19.') ||
        raw.startsWith('2605:59c0:') ||
        raw.startsWith('2605:59c1:')) {
      return 'Starlink (SpaceX)';
    }
    if (raw.startsWith('41.242.')) return 'Backbone Connectivity (BCN)';
    if (raw.startsWith('160.152.') || raw.startsWith('102.212.')) return 'Smile Communications';
    if (raw.startsWith('217.14.')) return 'Inq. Digital Nigeria';

    final clean = (explicitIsp ?? '').trim();
    if (clean.isNotEmpty && clean.toLowerCase() != 'unknown') {
      final l = clean.toLowerCase();
      if (l.contains('mtn')) return 'MTN Nigeria';
      if (l.contains('airtel') || l.contains('celtel') || l.contains('bharti')) return 'Airtel Nigeria';
      if (l.contains('globacom') || l.contains('glo ')) return 'Globacom (Glo)';
      if (l.contains('emts') || l.contains('9mobile') || l.contains('etisalat')) return '9mobile (EMTS)';
      if (l.contains('starlink') || l.contains('spacex')) return 'Starlink (SpaceX)';
      if (l.contains('spectranet')) return 'Spectranet';
      if (l.contains('ipnx')) return 'ipNX Nigeria';
      return clean;
    }
    return 'Mobile Carrier Network';
  }

  static Future<Map<String, String>> _resolveNetworkInfo() async {
    if (_cachedIp != null && _cachedIp!.isNotEmpty && _cachedIp != '127.0.0.1') {
      return {
        'ip': _cachedIp!,
        'isp': _cachedIsp ?? _inferIspFromIp(_cachedIp!),
      };
    }

    try {
      final res = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final ip = (data['ip'] ?? '').toString().trim();
        final conn = data['connection'] as Map<String, dynamic>?;
        final rawIsp = (conn?['isp'] ?? conn?['org'] ?? '').toString().trim();
        if (ip.isNotEmpty) {
          _cachedIp = ip;
          _cachedIsp = _inferIspFromIp(ip, rawIsp);
          return {'ip': _cachedIp!, 'isp': _cachedIsp!};
        }
      }
    } catch (_) {}

    try {
      final res = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final ip = (data['ip'] ?? '').toString().trim();
        if (ip.isNotEmpty) {
          _cachedIp = ip;
          _cachedIsp = _inferIspFromIp(ip);
          return {'ip': _cachedIp!, 'isp': _cachedIsp!};
        }
      }
    } catch (_) {}

    return {'ip': 'Unresolved IP', 'isp': 'Mobile Carrier Network'};
  }

  /// Records any mobile app activity into Firestore `audit_logs`
  /// with accurate user identity, real public IP, network provider, and `platform: 'mobile_app'`.
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

      final netInfo = await _resolveNetworkInfo();

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
        'ipAddress': netInfo['ip'],
        'networkProvider': netInfo['isp'],
        'method': 'mobile_app',
        'platform': 'mobile_app',
        'userAgent': 'VoteGuard Flutter Mobile (${defaultTargetPlatform.name})',
        'details': {
          'platform': 'mobile_app',
          'os': defaultTargetPlatform.name,
          'networkProvider': netInfo['isp'],
          ...?details,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AuditLogService notice: $e');
    }
  }
}
