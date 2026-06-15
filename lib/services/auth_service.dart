import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:voteguard/services/cloud_functions_service.dart';
import 'package:voteguard/services/notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();

  static const String _keyEmail = 'auth_email';
  static const String _keyPassword = 'auth_password';

  // Stream of auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
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
  Future<UserCredential?> signInByIdentifier(
    String identifier,
    String password,
  ) async {
    final trimmedIdentifier = identifier.trim();

    if (_looksLikeEmail(trimmedIdentifier)) {
      return signIn(trimmedIdentifier.toLowerCase(), password);
    }

    final result = await resolveLoginIdentifier(trimmedIdentifier);
    final email = result['email'] as String?;

    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'This user does not have an email address for Firebase login.',
      );
    }

    return signIn(email, password);
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
