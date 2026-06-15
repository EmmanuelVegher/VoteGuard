import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:voteguard/services/auth_service.dart';
import 'package:voteguard/services/notification_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late StreamSubscription<User?> _userSubscription;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthState.unknown()) {
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);

    _userSubscription = _authService.user.listen(
      (user) => add(AuthStatusChanged(user)),
    );
  }

  Future<void> _onAuthStatusChanged(
      AuthStatusChanged event, Emitter<AuthState> emit) async {
    if (event.user != null) {
      final user = event.user;
      if (user != null) {
        // Fetch role from Firestore
        final doc = await _firestore.collection('users').doc(user.uid).get();
        final role = doc.data()?['role'] as String? ?? 'OBSERVER';

        // Sync FCM push token for the authenticated user
        unawaited(NotificationService().updateTokenInFirestore(user.uid));

        emit(AuthState.authenticated(user, role: role));
      } else {
        emit(const AuthState.unauthenticated());
      }
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.authenticating());
    try {
      await _authService.signInByIdentifier(event.email, event.password);
    } catch (e) {
      emit(AuthState.failure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId != null) {
      try {
        await NotificationService().removeTokenInFirestore(currentUserId);
      } catch (e) {
        print('AuthBloc: Error removing notification token: $e');
      }
    }
    await _authService.signOut();
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
