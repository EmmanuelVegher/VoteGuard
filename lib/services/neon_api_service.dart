import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class NeonApiService {
  static const String _defaultBaseUrl = 'https://voteguard-backend--naijaobserve.us-east4.hosted.app/api';
  static final String baseUrl = const String.fromEnvironment(
    'VOTEGUARD_API_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyToken = 'trg_access_token';
  static const String _keyDeviceTrustToken = 'vg_device_trust_token';

  // Get stored headers including auth token & device trust token
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: _keyToken);
    final trustToken = await _storage.read(key: _keyDeviceTrustToken);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (trustToken != null && trustToken.isNotEmpty) {
      headers['X-Device-Trust-Token'] = trustToken;
    }

    return headers;
  }

  // 1. Mobile Login with 2FA, Device Trust & DoS Safeguards
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    String? twoFactorCode,
    String? captchaToken,
    String? deviceApprovalCode,
    bool trustDevice = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'identifier': identifier.trim(),
        'password': password,
        if (twoFactorCode != null && twoFactorCode.isNotEmpty)
          'twoFactorCode': twoFactorCode,
        if (captchaToken != null && captchaToken.isNotEmpty)
          'captchaToken': captchaToken,
        if (deviceApprovalCode != null && deviceApprovalCode.isNotEmpty)
          'deviceApprovalCode': deviceApprovalCode,
        'trustDevice': trustDevice,
        'rememberDevice': trustDevice,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: headers,
        body: body,
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['accessToken'] != null) {
          await _storage.write(key: _keyToken, value: data['accessToken']);
        }
        if (data['trustedDeviceToken'] != null) {
          await _storage.write(
              key: _keyDeviceTrustToken, value: data['trustedDeviceToken']);
        }
      }

      return data;
    } catch (e) {
      debugPrint('NeonApiService login error: $e');
      return {
        'success': false,
        'error': 'Network connection failed. Please check internet connection.',
      };
    }
  }

  // 2. Register Trusted Device
  static Future<bool> registerTrustedDevice() async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/trust-device'),
        headers: headers,
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true && data['trustedDeviceToken'] != null) {
        await _storage.write(
            key: _keyDeviceTrustToken, value: data['trustedDeviceToken']);
        return true;
      }
    } catch (e) {
      debugPrint('NeonApiService trust-device error: $e');
    }
    return false;
  }

  // 3. Submit Checklist directly to Neon PostgreSQL
  static Future<Map<String, dynamic>> submitChecklist({
    required String electionId,
    required String state,
    required String lga,
    required String ward,
    required String pollingUnit,
    required Map<String, dynamic> answers,
    String status = 'submitted',
    DateTime? timeOfArrival,
    DateTime? timeOfDeparture,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'electionId': electionId,
        'state': state,
        'lga': lga,
        'ward': ward,
        'pollingUnit': pollingUnit,
        'answers': answers,
        'status': status,
        if (timeOfArrival != null)
          'timeOfArrival': timeOfArrival.toIso8601String(),
        if (timeOfDeparture != null)
          'timeOfDeparture': timeOfDeparture.toIso8601String(),
      });

      final response = await http.post(
        Uri.parse('$baseUrl/observer/checklist'),
        headers: headers,
        body: body,
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NeonApiService submitChecklist error: $e');
      return {
        'success': false,
        'error': 'Neon API checklist submission failed: $e',
      };
    }
  }

  // 4. Submit Incident Report directly to Neon PostgreSQL
  static Future<Map<String, dynamic>> submitIncident({
    required String electionId,
    required String state,
    required String lga,
    required String ward,
    required String pollingUnit,
    required String incidentType,
    required String description,
    List<String> mediaUrls = const [],
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'electionId': electionId,
        'state': state,
        'lga': lga,
        'ward': ward,
        'pollingUnit': pollingUnit,
        'incidentType': incidentType,
        'description': description,
        'mediaUrls': mediaUrls,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/observer/incident'),
        headers: headers,
        body: body,
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NeonApiService submitIncident error: $e');
      return {
        'success': false,
        'error': 'Neon API incident submission failed: $e',
      };
    }
  }

  // 5. Submit Election Results directly to Neon PostgreSQL
  static Future<Map<String, dynamic>> submitResult({
    required String electionId,
    required String state,
    required String lga,
    required String ward,
    required String pollingUnit,
    required String party,
    required int votes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'state': state,
        'lga': lga,
        'ward': ward,
        'pollingUnit': pollingUnit,
        'party': party,
        'votes': votes,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/elections/$electionId/results'),
        headers: headers,
        body: body,
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NeonApiService submitResult error: $e');
      return {
        'success': false,
        'error': 'Neon API result submission failed: $e',
      };
    }
  }

  // 6. Log Audit Activity (dual-persisted to Neon PostgreSQL & Firestore)
  static Future<void> logAudit({
    required String action,
    required String resource,
    String? userId,
    String? userRole,
    Map<String, dynamic>? details,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'action': action,
        'resource': resource,
        if (userId != null) 'userId': userId,
        if (userRole != null) 'userRole': userRole,
        if (details != null) 'details': details,
      });

      await http.post(
        Uri.parse('$baseUrl/activity-logs'),
        headers: headers,
        body: body,
      );
    } catch (e) {
      debugPrint('NeonApiService logAudit error: $e');
    }
  }

  // 7. Delete Checklist from Neon PostgreSQL
  static Future<Map<String, dynamic>> deleteChecklist({
    required String electionId,
    required String pollingUnit,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/observer/checklist').replace(queryParameters: {
        'electionId': electionId,
        'pollingUnit': pollingUnit,
      });

      final response = await http.delete(uri, headers: headers);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NeonApiService deleteChecklist error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // 8. Delete Incident from Neon PostgreSQL
  static Future<Map<String, dynamic>> deleteIncident(String incidentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/observer/incidents/$incidentId'),
        headers: headers,
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('NeonApiService deleteIncident error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
