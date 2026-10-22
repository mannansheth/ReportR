import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/app.dart';
import 'package:reportr_flutter/l10n/app_localizations_hi.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:reportr_flutter/core/storage/secure_storage_service.dart';
import 'package:reportr_flutter/models/user_session.dart';
import 'package:reportr_flutter/services/auth_service.dart';
import 'package:reportr_flutter/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows login when no session exists', (tester) async {
    final controller = await _buildController();

    await tester.pumpWidget(ReportRApp(controller: controller));

    expect(find.text('Welcome to ReportR'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });

  testWidgets('legacy session without an auth token returns to login', (
    tester,
  ) async {
    final storage = _MemorySecureStorageService();
    await storage.write(
      'userDetails',
      const UserSession(
        id: '123',
        name: 'Legacy',
        number: '9999999901',
      ).toJsonString(),
    );
    final controller = await _buildController(storage: storage);
    await tester.pumpWidget(ReportRApp(controller: controller));
    expect(controller.isLoggedIn, isFalse);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.text('Dev-only tools'), findsNothing);
  });
  testWidgets(
    'OTP flow sends token, stores verified session, and opens shell',
    (tester) async {
      final storage = _MemorySecureStorageService();
      final client = _FakeAuthClient([
        {'success': true, 'message': 'OTP sent'},
        {
          'success': true,
          'authToken': 'test-auth-token',
          'user': {'id': 7, 'name': 'Real User', 'phone': '9998887777'},
        },
      ]);
      final controller = await _buildController(
        storage: storage,
        authService: AuthService(client),
        initialPreferences: {'token': 'fcm-token'},
      );

      await tester.pumpWidget(ReportRApp(controller: controller));
      await tester.enterText(find.bySemanticsLabel('Name'), 'Real User');
      await tester.enterText(
        find.bySemanticsLabel('Phone number'),
        '9998887777',
      );
      await tester.ensureVisible(find.text('Send OTP'));
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('OTP'), findsOneWidget);
      await tester.enterText(find.bySemanticsLabel('OTP'), '123456');
      await tester.ensureVisible(find.text('Verify OTP'));
      await tester.tap(find.text('Verify OTP'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Reports'), findsWidgets);
      expect(controller.session?.name, 'Real User');
      expect(controller.authToken, 'test-auth-token');
      expect(client.requests.first.path, 'api/user/sendOTP');
      expect(client.requests.first.body['token'], 'fcm-token');
      expect(client.requests.last.path, 'api/user/verifyOTP');
      expect(client.requests.last.body['otp'], '123456');
      expect(await storage.read('userDetails'), contains('Real User'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 16));
    },
  );

  testWidgets('language preference can switch to Hindi', (tester) async {
    final controller = await _buildController();

    await tester.pumpWidget(ReportRApp(controller: controller));
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hindi').last);
    await tester.pumpAndSettle();

    expect(find.text(AppLocalizationsHi().authWelcome), findsOneWidget);
  });

  test('malformed session JSON returns null', () {
    expect(UserSession.fromJsonString('{bad json'), isNull);
    expect(UserSession.fromJsonString('{"id":1}'), isNull);
  });
}

Future<AppController> _buildController({
  SecureStorageService? storage,
  AuthService? authService,
  Map<String, Object>? initialPreferences,
}) async {
  SharedPreferences.setMockInitialValues(initialPreferences ?? {});
  final preferences = await PreferencesService.create();
  final controller = AppController(
    sessionService: SessionService(storage ?? _MemorySecureStorageService()),
    preferencesService: preferences,
    authService: authService ?? AuthService(_FakeAuthClient()),
  );
  await controller.load();
  return controller;
}

class _MemorySecureStorageService extends SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<bool> write(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> delete(String key) async {
    _values.remove(key);
    return true;
  }
}

class _Request {
  const _Request(this.path, this.body);

  final String path;
  final Map<String, dynamic> body;
}

class _FakeAuthClient implements AuthClient {
  _FakeAuthClient([List<Map<String, dynamic>>? responses])
    : _responses = responses ?? [];

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
