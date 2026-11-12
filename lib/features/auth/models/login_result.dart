import 'auth_tokens.dart';
import 'auth_user.dart';

class LoginResult {
  const LoginResult({required this.tokens, required this.user});

  final AuthTokens tokens;
  final AuthUser user;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      tokens: AuthTokens.fromJson(json),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
