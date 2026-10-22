import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/services/auth_service.dart';

void main() {
  test('sendOtp preserves backend request shape and maps success', () async {
    final client = _FakeAuthClient([
      {'success': true, 'message': 'OTP sent'},
    ]);
    final service = AuthService(client);

    final result = await service.sendOtp(
      name: ' Example ',
      phone: ' 9876543210 ',
      token: 'fcm-token',
    );

    expect(result.isSuccess, isTrue);
    expect(client.requests.single.path, 'api/user/sendOTP');
    expect(client.requests.single.body, {
      'name': 'Example',
      'phone': '9876543210',
      'token': 'fcm-token',
    });
  });

  test('sendOtp maps backend success false to a failure message', () async {
    final service = AuthService(
      _FakeAuthClient([
        {'success': false, 'message': 'FCM token required'},
      ]),
    );

    final result = await service.sendOtp(
      name: 'Example',
      phone: '9876543210',
      token: 'fcm-token',
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, 'FCM token required');
  });

  test('verifyOtp maps backend user to stored session shape', () async {
    final client = _FakeAuthClient([
      {
        'success': true,
        'user': {'id': 42, 'name': 'Example', 'phone': '9876543210'},
      },
    ]);
    final service = AuthService(client);

    final result = await service.verifyOtp(
      name: 'Example',
      phone: '9876543210',
      otp: '123456',
      token: 'fcm-token',
    );

    expect(result.isSuccess, isTrue);
    expect(result.data!.id, '42');
    expect(result.data!.name, 'Example');
    expect(result.data!.number, '9876543210');
    expect(client.requests.single.path, 'api/user/verifyOTP');
    expect(client.requests.single.body, {
      'name': 'Example',
      'phone': '9876543210',
      'otp': '123456',
      'token': 'fcm-token',
    });
  });

  test('verifyOtp maps invalid or expired OTP response to failure', () async {
    final service = AuthService(
      _FakeAuthClient([
        {'success': false, 'message': 'Invalid or expired OTP'},
      ]),
    );

    final result = await service.verifyOtp(
      name: 'Example',
      phone: '9876543210',
      otp: '000000',
      token: 'fcm-token',
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, 'Invalid or expired OTP');
  });

  test('verifyOtp rejects malformed success response', () async {
    final service = AuthService(
      _FakeAuthClient([
        {'success': true},
      ]),
    );

    final result = await service.verifyOtp(
      name: 'Example',
      phone: '9876543210',
      otp: '123456',
      token: 'fcm-token',
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, 'Backend returned an invalid user.');
  });

  test('client exceptions are reported without throwing', () async {
    final service = AuthService(_ThrowingAuthClient());

    final result = await service.sendOtp(
      name: 'Example',
      phone: '9876543210',
      token: 'fcm-token',
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, 'Backend base URL is not configured.');
  });
}

class _Request {
  const _Request(this.path, this.body);

  final String path;
  final Map<String, dynamic> body;
}

class _FakeAuthClient implements AuthClient {
  _FakeAuthClient(this._responses);

  final List<Map<String, dynamic>> _responses;
  final List<_Request> requests = [];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    requests.add(_Request(path, body));
    return _responses.removeAt(0);
  }
}

class _ThrowingAuthClient implements AuthClient {
  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    throw const ApiClientException('Backend base URL is not configured.');
  }
}
