import 'user_session.dart';

class AuthResult<T> {
  const AuthResult._({required this.isSuccess, this.data, this.message, this.authToken});

  final bool isSuccess;
  final T? data;
  final String? message;
  final String? authToken;

  factory AuthResult.success({T? data, String? authToken}) {
    return AuthResult._(isSuccess: true, data: data, authToken: authToken);
  }

  factory AuthResult.failure(String message) {
    return AuthResult._(isSuccess: false, message: message);
  }
}

typedef SendOtpResult = AuthResult<void>;
typedef VerifyOtpResult = AuthResult<UserSession>;