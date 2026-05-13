part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, authenticating, failure }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState._({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
  });

  const AuthState.unknown() : this._();

  const AuthState.authenticating() : this._(status: AuthStatus.authenticating);

  const AuthState.authenticated(User user)
      : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);

  const AuthState.failure(String message)
      : this._(status: AuthStatus.failure, errorMessage: message);

  @override
  List<Object?> get props => [status, user, errorMessage];
}
