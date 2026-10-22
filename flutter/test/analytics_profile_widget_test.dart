import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportr_flutter/app.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:reportr_flutter/core/storage/secure_storage_service.dart';
import 'package:reportr_flutter/l10n/app_localizations.dart';
import 'package:reportr_flutter/models/report_record.dart';
import 'package:reportr_flutter/models/user_session.dart';
import 'package:reportr_flutter/screens/analytics/analytics_screen.dart';
import 'package:reportr_flutter/screens/profile/profile_screen.dart';
import 'package:reportr_flutter/services/auth_service.dart';
import 'package:reportr_flutter/services/profile_service.dart';
import 'package:reportr_flutter/services/report_service.dart';
import 'package:reportr_flutter/services/session_service.dart';

const user = UserSession(id: '1', name: 'Test User', number: '9998887777');

class MemoryStorage extends SecureStorageService {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, String value) async {
    values[key] = value;
    return true;
  }

  @override
  Future<bool> delete(String key) async {
    values.remove(key);
    return true;
  }
}

class FakeProfile extends ProfileService {
  FakeProfile({
    this.fail = false,
    this.freshName = 'Test User',
    this.fetchFails = false,
  }) : super(ApiClient());
  final bool fail;
  final String freshName;
  final bool fetchFails;
  int reads = 0;
  @override
  Future<UserSession> getProfile() async {
    reads++;
    if (fetchFails) throw const ApiClientException('Profile unavailable');
    return UserSession(id: user.id, name: freshName, number: user.number);
  }

  @override
  Future<UserSession> updateName(String name) async {
    if (fail) throw const ApiClientException('Profile update unavailable');
    return UserSession(id: user.id, name: name, number: user.number);
  }
}

class FakeReports extends ReportService {
  FakeReports() : super(ApiClient());
  @override
  Future<List<ReportRecord>> getUserReports(String userId) async => [
    ReportRecord(
      id: '1',
      userId: userId,
      issue: 'Pothole',
      description: '',
      location: const {},
      createdAt: DateTime.now().toIso8601String(),
      status: 'Resolved',
    ),
    ReportRecord(
      id: '2',
      userId: userId,
      issue: 'Garbage',
      description: '',
      location: const {},
      createdAt: DateTime.now().toIso8601String(),
      status: 'In Progress',
    ),
  ];
}

Widget wrap(Widget screen) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: screen),
);
Future<AppController> controller() async {
  SharedPreferences.setMockInitialValues({});
  final result = AppController(
    sessionService: SessionService(MemoryStorage()),
    preferencesService: await PreferencesService.create(),
    authService: AuthService(ApiClient()),
  );
  await result.load();
  await result.saveSession(user, authToken: 'test-token');
  return result;
}

void main() {
  testWidgets(
    'profile refreshes backend data on tab entry and preserves token',
    (tester) async {
      final app = await controller();
      final service = FakeProfile(freshName: 'Updated elsewhere');
      await tester.pumpWidget(
        wrap(
          ProfileScreen(
            controller: app,
            profileService: service,
            isActive: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.reads, 0);
      await tester.pumpWidget(
        wrap(
          ProfileScreen(
            controller: app,
            profileService: service,
            isActive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.reads, 1);
      expect(app.session!.name, 'Updated elsewhere');
      expect(app.authToken, 'test-token');
      expect(find.text('Updated elsewhere'), findsWidgets);
    },
  );
  testWidgets('profile fetch failure retains cached account and offers retry', (
    tester,
  ) async {
    final app = await controller();
    await tester.pumpWidget(
      wrap(
        ProfileScreen(
          controller: app,
          profileService: FakeProfile(fetchFails: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(app.session!.name, 'Test User');
    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
  testWidgets('analytics renders real totals and resolution percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(AnalyticsScreen(session: user, reportService: FakeReports())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile name update persists and failure leaves original name', (
    tester,
  ) async {
    final app = await controller();
    await tester.pumpWidget(
      wrap(
        ProfileScreen(controller: app, profileService: FakeProfile(fail: true)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'New Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.session!.name, 'Test User');
    expect(find.text('Profile update unavailable'), findsOneWidget);
    await tester.pumpWidget(
      wrap(
        ProfileScreen(
          key: const ValueKey('success'),
          controller: app,
          profileService: FakeProfile(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'New Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.session!.name, 'New Name');
    expect(app.authToken, 'test-token');
  });
  testWidgets(
    'sign out requires confirmation and clears session and auth token',
    (tester) async {
      final app = await controller();
      await tester.pumpWidget(
        wrap(ProfileScreen(controller: app, profileService: FakeProfile())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Sign out'), 300);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.session, isNotNull);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();
      expect(app.session, isNull);
      expect(app.authToken, isNull);
    },
  );
}
