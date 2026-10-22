import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportr_flutter/app.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:reportr_flutter/core/storage/secure_storage_service.dart';
import 'package:reportr_flutter/l10n/app_localizations.dart';
import 'package:reportr_flutter/l10n/general_translations.dart';
import 'package:reportr_flutter/l10n/ui_strings.dart';
import 'package:reportr_flutter/models/prediction.dart';
import 'package:reportr_flutter/models/report_record.dart';
import 'package:reportr_flutter/models/user_session.dart';
import 'package:reportr_flutter/screens/authority/authority_shell.dart';
import 'package:reportr_flutter/screens/home/camera_home_screen.dart';
import 'package:reportr_flutter/screens/login/login_screen.dart';
import 'package:reportr_flutter/screens/map/map_screen.dart';
import 'package:reportr_flutter/services/auth_service.dart';
import 'package:reportr_flutter/services/authority_service.dart';
import 'package:reportr_flutter/services/prediction_service.dart';
import 'package:reportr_flutter/services/session_service.dart';
import 'package:reportr_flutter/services/google_maps_config_service.dart';
import 'package:reportr_flutter/widgets/prediction_options.dart';

class MemoryStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
}

class FakeAuthority extends AuthorityService {
  FakeAuthority() : super(ApiClient());
  @override
  Future<List<ReportRecord>> getReports({String? status}) async => [
    const ReportRecord(
      id: 'r1',
      userId: '1',
      issue: 'Pothole, Garbage',
      description: 'माझी मूळ तक्रार',
      location: {},
      createdAt: '2026-10-15T10:30:00Z',
      status: 'In Progress',
    ),
  ];
}

Future<AppController> controller() async {
  SharedPreferences.setMockInitialValues({});
  final app = AppController(
    sessionService: SessionService(MemoryStorage()),
    preferencesService: await PreferencesService.create(),
    authService: AuthService(ApiClient()),
  );
  await app.load();
  return app;
}

Widget wrap(String language, Widget body) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: body),
);
void main() {
  test('known product keys have complete Hindi and Marathi translations', () {
    expect(
      generalTranslations['hi']!.keys.toSet(),
      generalTranslations['mr']!.keys.toSet(),
    );
    for (final language in ['hi', 'mr']) {
      for (final entry in generalTranslations[language]!.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        expect(const UiStrings('en').text(entry.key), entry.key);
        expect(
          UiStrings(language).text(entry.key),
          isNot(entry.key),
          reason: '${entry.key} in $language',
        );
      }
    }
  });
  test(
    'categories statuses errors dates localize while user content remains unchanged',
    () async {
      await initializeDateFormatting();
      const hi = UiStrings('hi');
      const mr = UiStrings('mr');
      expect(hi.category('Pothole, Garbage'), 'सड़क में गड्ढा, कचरा');
      expect(mr.category(' pothole , Garbage'), 'रस्त्यावरील खड्डा, कचरा');
      expect(hi.status('Resolved'), isNot('Resolved'));
      expect(
        mr.text('Connection closed before full header was received'),
        isNot(contains('Connection')),
      );
      expect(
        hi.text('Request failed (503). Please try again.'),
        contains('503'),
      );
      expect(mr.text('माझी मूळ तक्रार'), 'माझी मूळ तक्रार');
      expect(hi.date(DateTime(2026, 10, 15)), isNot(contains('Oct')));
    },
  );
  testWidgets(
    'login map camera authority and prediction labels switch among locales',
    (tester) async {
      final app = await controller();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        GoogleMapsConfigService.channel,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          GoogleMapsConfigService.channel,
          null,
        ),
      );
      const prediction = Prediction(
        issue: 'Pothole',
        probability: .9,
        description: 'English API value',
        boundingBox: [0, 0, 500, 500],
      );
      for (final language in ['en', 'hi', 'mr']) {
        final ui = UiStrings(language);
        await tester.pumpWidget(wrap(language, LoginScreen(controller: app)));
        await tester.pumpAndSettle();
        expect(
          find.text(ui.text('A better neighbourhood starts with you.')),
          findsOneWidget,
        );
        await tester.pumpWidget(
          wrap(language, const MapScreen(isActive: false)),
        );
        await tester.pumpAndSettle();
        expect(find.text(ui.text('Search a location')), findsOneWidget);
        expect(find.text(ui.text('All reports')), findsOneWidget);
        await tester.pumpWidget(
          wrap(
            language,
            CameraHomeScreen(
              predictionService: PredictionService(ApiClient()),
              preferences: app.preferencesService,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(ui.text('Choose a photo')), findsOneWidget);
        await tester.pumpWidget(
          wrap(
            language,
            AuthorityShell(
              session: const UserSession(
                id: '1',
                name: 'Authority User',
                number: '9998887777',
                role: 'Authority',
              ),
              authToken: 'fake',
              service: FakeAuthority(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(ui.text('Authority reports')), findsOneWidget);
        expect(find.text(ui.category('Pothole, Garbage')), findsOneWidget);
        await tester.pumpWidget(
          wrap(
            language,
            PredictionOptions(
              predictions: const [prediction],
              selectedIssues: const {'pothole'},
              onToggle: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(ui.category('Pothole')), findsOneWidget);
        expect(prediction.issue, 'Pothole');
      }
    },
  );
}
