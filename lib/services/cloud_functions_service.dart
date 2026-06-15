import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class CloudFunctionsService {
  static const _defaultBaseUrl =
      'https://us-central1-naijaobserve.cloudfunctions.net';

  static Future<String> _baseUrl() async {
    final configuredBaseUrl = String.fromEnvironment(
      'CLOUD_FUNCTIONS_BASE_URL',
      defaultValue: '',
    );

    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('system_settings')
          .get();
      final valueStr = doc.data()?['value'] as String?;

      if (valueStr != null && valueStr.isNotEmpty) {
        final valueJson = jsonDecode(valueStr) as Map<String, dynamic>;
        final cloudBaseUrl = valueJson['cloud_functions_base_url'] as String?;

        if (cloudBaseUrl != null && cloudBaseUrl.isNotEmpty) {
          return cloudBaseUrl.replaceAll(RegExp(r'/+$'), '');
        }
      }
    } catch (_) {
      // Fall back to default base URL if settings are unavailable.
    }

    return _defaultBaseUrl;
  }

  Future<Map<String, dynamic>> callFunction(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('${await _baseUrl()}/$functionName'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.headers['content-type']?.contains('application/json') !=
        true) {
      throw StateError(
        'Cloud Function returned an unexpected HTML response. Check CLOUD_FUNCTIONS_BASE_URL or settings.system_settings.value.cloud_functions_base_url. Response: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(decoded['error'] ?? response.body);
    }

    return decoded;
  }
}
