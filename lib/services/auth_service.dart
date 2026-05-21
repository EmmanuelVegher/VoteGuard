import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

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

  // Securely save credentials for biometric login
  Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: _keyEmail, value: email);
    await _secureStorage.write(key: _keyPassword, value: password);
  }

  // Retrieve stored credentials
  Future<Map<String, String>?> getStoredCredentials() async {
    final email = await _secureStorage.read(key: _keyEmail);
    final password = await _secureStorage.read(key: _keyPassword);

    if (email != null && password != null && email.isNotEmpty && password.isNotEmpty) {
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
}
