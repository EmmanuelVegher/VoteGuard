import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:voteguard/services/cloud_functions_service.dart';
import 'package:voteguard/services/notification_service.dart';

import 'package:voteguard/services/neon_api_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();

  static const String _keyEmail = 'auth_email';
  static const String _keyPassword = 'auth_password';
  static const String _keyDeviceTrustToken = 'vg_device_trust_token';

  // Retrieve stored device trust token
  Future<String?> getDeviceTrustToken() async {
    return await _secureStorage.read(key: _keyDeviceTrustToken);
  }

  // Stream of auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn(
    String identifier,
    String password, {
    List<String>? emailCandidates,
    String? twoFactorCode,
    String? deviceApprovalCode,
    bool trustDevice = true,
  }) async {
    String? firebaseAuthError;

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 1: Attempt Firebase Auth direct sign-in first (Firebase-First)
    // ─────────────────────────────────────────────────────────────────────────
    final candidates = emailCandidates ??
        (identifier.contains('@') ? [identifier.trim().toLowerCase()] : []);

    for (final email in candidates) {
      try {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final firebaseUser = userCredential.user;
        if (firebaseUser != null) {
          final idToken = await firebaseUser.getIdToken();
          if (idToken != null && idToken.isNotEmpty) {
            // Exchange Firebase ID Token with Express backend for JWT + profile
            final apiRes = await NeonApiService.firebaseLogin(
              idToken: idToken,
              rememberDevice: trustDevice,
            );

            if (apiRes['requiresDeviceApproval'] == true) {
              return {
                'requiresDeviceApproval': true,
                'message': apiRes['message'] ??
                    'Authorization code sent to your registered email.',
              };
            }

            if (apiRes['requires2FA'] == true) {
              return {
                'requires2FA': true,
                'message': apiRes['message'],
              };
            }

            // If account status is blocked/deactivated on backend, throw error
            if (apiRes['accountStatus'] != null &&
                apiRes['accountStatus'] != 'ACTIVE' &&
                apiRes['error'] != null) {
              await _auth.signOut();
              throw Exception(apiRes['error']);
            }

            return {'success': true};
          }
        }
      } catch (e) {
        if (e.toString().contains('deactivated') ||
            e.toString().contains('pending') ||
            e.toString().contains('disabled')) {
          rethrow;
        }
        debugPrint('Firebase Auth sign-in attempt failed for $email: $e');
        if (e is FirebaseAuthException) {
          if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
            firebaseAuthError = 'Invalid email/phone number or password.';
          } else if (e.code == 'user-disabled') {
            firebaseAuthError =
                'Your account has been disabled. Please contact your administrator.';
          } else if (e.code == 'too-many-requests') {
            firebaseAuthError =
                'Too many failed login attempts. Please try again later.';
          } else {
            firebaseAuthError = e.message;
          }
        }
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STEP 2: Fallback to Postgres Express login (/api/auth/login)
    // For legacy users in Postgres that haven't been created in Firebase Auth yet
    // ─────────────────────────────────────────────────────────────────────────
    try {
      final response = await NeonApiService.login(
        identifier: identifier,
        password: password,
        twoFactorCode: twoFactorCode,
        deviceApprovalCode: deviceApprovalCode,
        trustDevice: trustDevice,
      );

      if (response['success'] == true) {
        if (response['requiresDeviceApproval'] == true) {
          return {
            'requiresDeviceApproval': true,
            'message': response['message'] ??
                'Authorization code sent to your registered email.',
          };
        }

        if (response['requires2FA'] == true) {
          return {
            'requires2FA': true,
            'message': response['message'],
          };
        }

        // Custom token login to Firebase to enable Firestore access
        final customToken = response['firebaseCustomToken'] as String?;
        if (customToken != null && customToken.isNotEmpty) {
          await _auth.signInWithCustomToken(customToken);
        }

        return {'success': true};
      }

      // If Postgres login returned account status error (e.g. Pending / Inactive), raise it
      if (response['accountStatus'] != null || response['error'] != null) {
        final err = response['error'] ?? response['message'];
        if (err != null &&
            err !=
                'Network connection failed. Please check internet connection.') {
          throw Exception(err);
        }
      }
    } catch (e) {
      if (e.toString().contains('account') ||
          e.toString().contains('disabled') ||
          e.toString().contains('pending') ||
          e.toString().contains('deactivated')) {
        rethrow;
      }
      debugPrint('Postgres fallback login error: $e');
    }

    // If both failed, throw error
    throw Exception(
        firebaseAuthError ?? 'Invalid email/phone number or password.');
  }

  // Resolve a login identifier to a Firestore user document through Cloud Functions.
  Future<Map<String, dynamic>> resolveLoginIdentifier(String identifier) async {
    final result = await _cloudFunctions.callFunction(
      'resolveLoginIdentifier',
      {'identifier': identifier},
    );

    return result;
  }

  // Sign in using email or normalized phone identifier.
  Future<Map<String, dynamic>> signInByIdentifier(
    String identifier,
    String password, {
    String? twoFactorCode,
    String? deviceApprovalCode,
    bool trustDevice = true,
  }) async {
    final trimmedIdentifier = identifier.trim();
    List<String> candidates = [];

    if (_looksLikeEmail(trimmedIdentifier)) {
      candidates.add(trimmedIdentifier.toLowerCase());
    } else {
      final digits = trimmedIdentifier.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        candidates.add('$digits@voteguard.com');
        if (digits.startsWith('0') && digits.length == 11) {
          candidates.add('234${digits.substring(1)}@voteguard.com');
        } else if (digits.startsWith('234') && digits.length == 13) {
          candidates.add('0${digits.substring(3)}@voteguard.com');
        }
      }
      // Also attempt Cloud Function resolution as fallback for custom emails
      try {
        final result = await resolveLoginIdentifier(trimmedIdentifier);
        final resolvedEmail = result['email'] as String?;
        if (resolvedEmail != null &&
            resolvedEmail.isNotEmpty &&
            !candidates.contains(resolvedEmail.toLowerCase())) {
          candidates.insert(0, resolvedEmail.toLowerCase());
        }
      } catch (e) {
        debugPrint('Cloud Function resolveLoginIdentifier notice: $e');
      }
    }

    return signIn(
      trimmedIdentifier,
      password,
      emailCandidates: candidates,
      twoFactorCode: twoFactorCode,
      deviceApprovalCode: deviceApprovalCode,
      trustDevice: trustDevice,
    );
  }

  // Send Firebase password reset email
  Future<void> resetPasswordByEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Send password reset OTP through Firestore + FCM/Cloud Function.
  Future<void> resetPasswordByPhone(String phoneNumber) async {
    await NotificationService().sendPasswordResetOtp(phoneNumber);
  }

  // Securely save credentials for biometric login
  Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: _keyEmail, value: email);
    await _secureStorage.write(key: _keyPassword, value: password);
  }

  // Retrieve stored credentials
  Future<Map<String, String>?> getStoredCredentials() async {
    final email = await _secureStorage.read(key: _keyEmail);
    final password = await _secureStorage.read(key: _keyPassword);

    if (email != null &&
        password != null &&
        email.isNotEmpty &&
        password.isNotEmpty) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  // Clear credentials (e.g. on explicit logout without remember me)
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _keyEmail);
    await _secureStorage.delete(key: _keyPassword);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  static String normalizePhone(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('234')) {
      return digits;
    }

    if (digits.startsWith('0')) {
      return '234${digits.substring(1)}';
    }

    return digits;
  }

  static bool _looksLikeEmail(String identifier) {
    return identifier.contains('@');
  }
}
