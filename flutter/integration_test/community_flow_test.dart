import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/l10n/app_localizations.dart';
import 'package:reportr_flutter/l10n/ui_strings.dart';
import 'package:reportr_flutter/models/community_report.dart';
import 'package:reportr_flutter/screens/analytics/analytics_screen.dart';
import 'package:reportr_flutter/screens/reports/community_report_detail_screen.dart';
import 'package:reportr_flutter/screens/reports/community_reports_screen.dart';
import 'package:reportr_flutter/services/community_service.dart';
import 'package:reportr_flutter/widgets/brand.dart';
import '../test/branding_community_analytics_test.dart' show FakeAnalytics;

// Deterministic device UI fixture. Server algorithms, auth and DB concurrency
// are exercised separately by backend npm run test:all without real AI uploads.
class DeviceCommunity extends CommunityService {
  DeviceCommunity() : super(ApiClient());
  bool confirmed = false, voted = false;
  CommunityReport get current => CommunityReport.fromJson({
    'Rid': 'device-community-fixture',
    'issue': 'Pothole',
    'description': 'Road damage near the community library.',
    'location': {'lat': 18.52, 'lng': 73.85, 'loc': 'Community library, Pune'},
    'status': 'Issue Raised',
    'createdAt': '2026-10-15T08:00:00Z',
    'priority': confirmed ? 79 : 67,
    'baselinePriority': 67,
    'confirmationCount': confirmed ? 2 : 1,
    'confirmedByMe': confirmed,
    'resolutionWeight': voted ? 1 : 0,
    'resolutionVoters': voted ? 1 : 0,
    'resolutionVotedByMe': voted,
    'myEvidenceState': 'none',
    'isOwner': false,
  });
  @override
  Future<CommunityPage> getReports({
    int page = 1,
    String sort = 'priority',
    CommunityPosition? location,
  }) async =>
      CommunityPage(reports: [current], total: 1, page: 1, hasMore: false);
  @override
  Future<CommunityReport> getReport(String id) async => current;
  @override
  Future<CommunityReport> confirm(String id, CommunityPosition location) async {
    confirmed = true;
    return current;
  }

  @override
  Future<CommunityReport> resolve(
    String id,
    CommunityPosition location, {
    String note = '',
    String? imagePath,
  }) async {
    voted = true;
    return current;
  }
}

class DeviceLocation extends CommunityLocationService {
  @override
  Future<CommunityPosition> currentPosition() async => CommunityPosition(
    latitude: 18.5201,
    longitude: 73.85,
    accuracy: 5,
    timestamp: DateTime.now(),
  );
}

Widget app(String language, Widget child) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: ThemeData(
    colorSchemeSeed: const Color(0xff2e7d32),
    useMaterial3: true,
  ),
  home: Scaffold(body: child),
);
Future<void> reveal(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    180,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android: original branding, public feed, nearby confirmation and repair evidence',
    (tester) async {
      await tester.pumpWidget(app('en', const BrandStartupScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReportRLogo), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('community-original-branding');
      final service = DeviceCommunity();
      await tester.pumpWidget(
        app(
          'en',
          CommunityReportsScreen(
            service: service,
            locationService: DeviceLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('community-public-feed');
      await reveal(tester, 'I see this too');
      await tester.tap(find.text('I see this too'));
      await tester.pumpAndSettle();
      expect(service.confirmed, isTrue);
      expect(find.text('Reported by 2 people'), findsOneWidget);
      expect(find.text('You confirmed this issue'), findsOneWidget);
      await tester.pumpWidget(
        app(
          'en',
          CommunityReportDetailScreen(
            report: service.current,
            service: service,
            locationService: DeviceLocation(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open my private report and PDF'), findsNothing);
      await reveal(tester, 'Report as resolved');
      await binding.takeScreenshot('community-resolution-details');
      await tester.tap(find.text('Report as resolved'));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose photo'), findsOneWidget);
      await binding.takeScreenshot('community-resolution-photo-options');
      await tester.tap(find.text('Submit resolution update'));
      await tester.pumpAndSettle();
      expect(service.voted, isTrue);
      expect(service.current.isResolved, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final language in ['en', 'hi', 'mr']) {
    testWidgets(
      'Android: public reports and analytics localized in $language',
      (tester) async {
        final service = DeviceCommunity();
        await tester.pumpWidget(
          app(
            language,
            CommunityReportsScreen(
              service: service,
              locationService: DeviceLocation(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        expect(
          find.text(UiStrings(language).text('Community issues')),
          findsOneWidget,
        );
        await binding.takeScreenshot('community-feed-$language');
        await tester.pumpWidget(
          app(
            language,
            AnalyticsScreen(session: null, analyticsService: FakeAnalytics()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('12'), findsOneWidget);
        await binding.takeScreenshot('community-analytics-$language');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
