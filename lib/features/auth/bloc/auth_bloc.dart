import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:voteguard/services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
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

  void _onAuthStatusChanged(AuthStatusChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      final user = event.user;
      if (user != null) {
        emit(AuthState.authenticated(user));
      } else {
        emit(AuthState.unauthenticated());
      }
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLoginRequested(LoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.authenticating());
    try {
      await _authService.signIn(event.email, event.password);
    } catch (e) {
      emit(AuthState.failure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(LogoutRequested event, Emitter<AuthState> emit) async {
    await _authService.signOut();
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
