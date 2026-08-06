part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, authenticating, failure, requires2FA, requiresDeviceApproval }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;
  final String? role;
  
  // Pending credentials for multi-step verification (2FA/Device Approval)
  final String? pendingEmail;
  final String? pendingPassword;

  const AuthState._({
    this.status = AuthStatus.unknown,
    this.user,
    this.role,
    this.errorMessage,
    this.pendingEmail,
    this.pendingPassword,
  });

  const AuthState.unknown() : this._();

  const AuthState.authenticating() : this._(status: AuthStatus.authenticating);

  const AuthState.authenticated(User user, {String? role})
      : this._(status: AuthStatus.authenticated, user: user, role: role);

  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);

  const AuthState.failure(String message)
      : this._(status: AuthStatus.failure, errorMessage: message);

  const AuthState.requires2FA(String email, String password)
      : this._(
          status: AuthStatus.requires2FA,
          pendingEmail: email,
          pendingPassword: password,
        );

  const AuthState.requiresDeviceApproval(String email, String password, {String? message})
      : this._(
          status: AuthStatus.requiresDeviceApproval,
          pendingEmail: email,
          pendingPassword: password,
          errorMessage: message,
        );

  @override
  List<Object?> get props => [status, user, role, errorMessage, pendingEmail, pendingPassword];
}
