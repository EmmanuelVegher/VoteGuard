part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStatusChanged extends AuthEvent {
  final User? user;
  const AuthStatusChanged(this.user);

  @override
  List<Object?> get props => [user];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  final String? twoFactorCode;
  final String? deviceApprovalCode;
  final bool rememberMe;
  const LoginRequested({
    required this.email,
    required this.password,
    this.twoFactorCode,
    this.deviceApprovalCode,
    this.rememberMe = false,
  });

  @override
  List<Object?> get props => [email, password, twoFactorCode, deviceApprovalCode, rememberMe];
}

class LogoutRequested extends AuthEvent {}
