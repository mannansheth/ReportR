import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/models/community_report.dart';
import 'package:reportr_flutter/screens/reports/reports_screen.dart';
import 'package:reportr_flutter/screens/reports/community_report_detail_screen.dart';
import 'package:reportr_flutter/screens/reports/community_reports_screen.dart';
import 'package:reportr_flutter/services/community_service.dart';

CommunityReport fixture({
  bool confirmed = false,
  double weight = 0,
  String evidence = 'none',
  bool resolved = false,
}) => CommunityReport.fromJson({
  'Rid': 'public-r1',
  'issue': 'Pothole',
  'description': 'Public road damage',
  'location': {'lat': 0, 'lng': 0, 'loc': 'Public square'},
  'status': resolved ? 'Resolved' : 'Issue Raised',
  'createdAt': '2026-10-15T08:00:00Z',
  'confirmationCount': confirmed ? 2 : 1,
  'confirmedByMe': confirmed,
  'priority': 70,
  'baselinePriority': 60,
  'resolutionWeight': weight,
  'resolutionVoters': weight > 0 ? 1 : 0,
  'resolutionVotedByMe': weight > 0,
  'myEvidenceState': evidence,
});

class LocationFixture extends CommunityLocationService {
  LocationFixture(this.latitude);
  final double latitude;
  int calls = 0;
  @override
  Future<CommunityPosition> currentPosition() async {
    calls++;
    return CommunityPosition(
      latitude: latitude,
      longitude: 0,
      accuracy: 5,
      timestamp: DateTime.now(),
    );
  }
}

class CommunityFixture extends CommunityService {
  CommunityFixture() : super(ApiClient());
  CommunityReport current = fixture();
  int confirmations = 0, resolutions = 0, loads = 0;
  @override
  Future<CommunityPage> getReports({
    int page = 1,
    String sort = 'priority',
    CommunityPosition? location,
  }) async {
    loads++;
    return CommunityPage(
      reports: [current],
      total: 1,
      page: page,
      hasMore: false,
    );
  }

  @override
  Future<CommunityReport> getReport(String id) async => current;
  @override
  Future<CommunityReport> confirm(String id, CommunityPosition location) async {
    confirmations++;
    return current = fixture(confirmed: true);
  }

  @override
  Future<CommunityReport> resolve(
    String id,
    CommunityPosition location, {
    String note = '',
    String? imagePath,
  }) async {
    resolutions++;
    return current = fixture(weight: 1);
  }
}

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
  home: Scaffold(body: child),
);

Future<void> scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(text));
}

void main() {
  testWidgets('legacy or authority resolution never invents community verification provenance', (tester) async {
    final service = CommunityFixture()..current = fixture(resolved: true);
    await tester.pumpWidget(app(CommunityReportDetailScreen(report: service.current, service: service)));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Issue resolved');
    expect(find.text('Verified by the community'), findsNothing);
    expect(find.text('No community resolution contributions are recorded for this issue.'), findsOneWidget);
    expect(find.text('0.0 / 5 verification points · 0 people'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'feed card confirms directly with fresh GPS and refreshed community count',
    (tester) async {
      final service = CommunityFixture();
      final location = LocationFixture(.001);
      await tester.pumpWidget(
        app(
          CommunityReportsScreen(service: service, locationService: location),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, 'I see this too');
      await tester.tap(find.text('I see this too'));
      await tester.pumpAndSettle();
      expect(service.confirmations, 1);
      expect(location.calls, 1);
      expect(find.text('Reported by 2 people'), findsOneWidget);
      expect(find.text('You confirmed this issue'), findsOneWidget);
      expect(find.text('I see this too'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending photo vote can be upgraded without claiming verified evidence',
    (tester) async {
      final service = CommunityFixture()
        ..current = fixture(weight: 1, evidence: 'pending');
      final location = LocationFixture(.001);
      await tester.pumpWidget(
        app(
          CommunityReportDetailScreen(
            report: service.current,
            service: service,
            locationService: location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Add or update repair photo');
      expect(find.text('Your repair photo is verified'), findsNothing);
      await tester.tap(find.text('Add or update repair photo'));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose photo'), findsOneWidget);
      expect(find.text('Submit resolution update'), findsOneWidget);
      expect(service.resolutions, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'resolution outside 200 metres is rejected before requesting evidence',
    (tester) async {
      final service = CommunityFixture();
      final location = LocationFixture(.003);
      await tester.pumpWidget(
        app(
          CommunityReportDetailScreen(
            report: service.current,
            service: service,
            locationService: location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Report as resolved');
      await tester.tap(find.text('Report as resolved'));
      await tester.pumpAndSettle();
      expect(service.resolutions, 0);
      expect(find.text('What has been fixed?'), findsNothing);
      await scrollTo(
        tester,
        'Move within 200 metres of the issue to report it resolved.',
      );
      expect(
        find.text('Move within 200 metres of the issue to report it resolved.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reports default to public community feed, not an empty personal list',
    (tester) async {
      final service = CommunityFixture();
      await tester.pumpWidget(
        app(ReportsScreen(session: null, communityService: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Community issues'), findsOneWidget);
      expect(find.text('Pothole'), findsOneWidget);
      expect(find.text('Report PDF'), findsNothing);
      expect(service.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'public report cannot reveal owner PDF and rejects confirmation beyond 500m',
    (tester) async {
      final service = CommunityFixture();
      final location = LocationFixture(.01);
      await tester.pumpWidget(
        app(
          CommunityReportDetailScreen(
            report: fixture(),
            service: service,
            locationService: location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open my private report and PDF'), findsNothing);
      await scrollTo(tester, 'I see this too');
      await tester.tap(find.text('I see this too'));
      await tester.pumpAndSettle();
      expect(service.confirmations, 0);
      expect(location.calls, 1);
      await scrollTo(
        tester,
        'Move within 500 metres of the issue to confirm it.',
      );
      expect(
        find.text('Move within 500 metres of the issue to confirm it.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'nearby confirmation refreshes counts, prevents repeated client vote and signals duplicate join',
    (tester) async {
      final service = CommunityFixture();
      final location = LocationFixture(.001);
      int joined = 0;
      await tester.pumpWidget(
        app(
          CommunityReportDetailScreen(
            report: fixture(),
            service: service,
            locationService: location,
            onConfirmed: () => joined++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, 'I see this too');
      await tester.tap(find.text('I see this too'));
      await tester.pumpAndSettle();
      expect(service.confirmations, 1);
      expect(joined, 1);
      expect(find.text('You confirmed this issue'), findsOneWidget);
      expect(find.text('2 community confirmations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'nearby resolution accepts optional text evidence and stays pending until verified',
    (tester) async {
      final service = CommunityFixture();
      final location = LocationFixture(.001);
      await tester.pumpWidget(
        app(
          CommunityReportDetailScreen(
            report: fixture(),
            service: service,
            locationService: location,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, 'Report as resolved');
      await tester.tap(find.text('Report as resolved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit resolution update'));
      await tester.pumpAndSettle();
      expect(service.resolutions, 1);
      expect(location.calls, 2);
      expect(find.text('Add or update repair photo'), findsOneWidget);
      expect(
        find.text('The community has verified this issue as resolved.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
