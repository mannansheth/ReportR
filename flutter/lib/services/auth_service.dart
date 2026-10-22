import '../core/network/api_client.dart';
import '../models/auth_result.dart';
import '../models/user_session.dart';

class AuthService {
  const AuthService(this._client);

  final AuthClient _client;

  Future<SendOtpResult> sendOtp({
    required String name,
    required String phone,
    required String token,
  }) async {
    if (name.trim().isEmpty || phone.trim().isEmpty) {
      return SendOtpResult.failure('Please enter a valid phone number');
    }
    if (token.trim().isEmpty) {
      return SendOtpResult.failure('Push notification token is not available yet.');
    }

    try {
      final data = await _client.postJson('api/user/sendOTP', {
        'name': name.trim(),
        'phone': phone.trim(),
        'token': token,
      });
      if (data['success'] == true) return SendOtpResult.success();
      return SendOtpResult.failure(_messageFrom(data, 'Failed to send OTP.'));
    } catch (error) {
      return SendOtpResult.failure(_errorMessage(error));
    }
  }

  Future<VerifyOtpResult> verifyOtp({
    required String name,
    required String phone,
    required String otp,
    required String token,
  }) async {
    if (name.trim().isEmpty || phone.trim().isEmpty || otp.trim().isEmpty) {
      return VerifyOtpResult.failure('Please enter a valid OTP.');
    }

    try {
      final data = await _client.postJson('api/user/verifyOTP', {
        'name': name.trim(),
        'phone': phone.trim(),
        'otp': otp.trim(),
        'token': token,
      });
      if (data['success'] != true) {
        return VerifyOtpResult.failure(_messageFrom(data, 'Invalid or expired OTP.'));
      }

      final user = data['user'];
      if (user is! Map) {
        return VerifyOtpResult.failure('Backend returned an invalid user.');
      }

      final id = user['id'];
      final backendName = user['name'];
      final backendPhone = user['phone'];
      if (id == null || backendName == null || backendPhone == null) {
        return VerifyOtpResult.failure('Backend returned an incomplete user.');
      }

      return VerifyOtpResult.success(data: UserSession(
          id: id.toString(),
          name: backendName.toString(),
          number: backendPhone.toString(),
          role: user['role']?.toString() ?? 'Citizen',
        ),
        authToken: data['authToken']?.toString(),
      );
    } catch (error) {
      return VerifyOtpResult.failure(_errorMessage(error));
    }
  }

  String _messageFrom(Map<String, dynamic> data, String fallback) {
    final message = data['message'] ?? data['error'];
    if (message is String && message.trim().isNotEmpty) return message;
    return fallback;
  }

  String _errorMessage(Object error) {
    if (error is ApiClientException) return error.message;
    return 'Network request failed.';
  }
}
