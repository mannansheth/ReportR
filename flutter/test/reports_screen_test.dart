import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/models/report_record.dart';
import 'package:reportr_flutter/models/user_session.dart';
import 'package:reportr_flutter/screens/reports/reports_screen.dart';
import 'package:reportr_flutter/services/report_service.dart';

const record = ReportRecord(
  id: 'Rid_pdf_visible',
  userId: '1',
  issue: 'Pothole',
  description: 'Deep road damage',
  location: {'lat': 19.1, 'lng': 72.8, 'loc': 'Mumbai'},
  createdAt: '2026-10-15T08:00:00Z',
  status: 'Issue Raised',
);

class ReportsFixtureService extends ReportService {
  ReportsFixtureService() : super(ApiClient());
  @override
  Future<List<ReportRecord>> getUserReports(String userId) async => [record];
  @override
  Future<ReportRecord> getReportDetails({
    required String reportId,
    required String userId,
  }) async => record;
  @override
  Future<List<ReportStatusEvent>> getStatusHistory({
    required String reportId,
  }) async => const [];
}

Widget app(Widget screen, String language) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: screen),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('report list exposes PDF even when remote URL is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ReportsScreen(
          initialMine: true,
          session: const UserSession(
            id: '1',
            name: 'Test',
            number: '9999999999',
          ),
          reportService: ReportsFixtureService(),
        ),
        'en',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Report PDF'), findsOneWidget);
    expect(find.text('Pothole'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'detail exposes report PDF without remote URL and localizes in Hindi',
    (tester) async {
      await tester.pumpWidget(
        app(
          ReportDetailScreen(report: record, service: ReportsFixtureService()),
          'hi',
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('रिपोर्ट PDF खोलें'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('रिपोर्ट PDF खोलें'), findsOneWidget);
      expect(
        find.text('View, download or share your report document.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Marathi report search matches original category and keeps canonical filters',
    (tester) async {
      await tester.pumpWidget(
        app(
          ReportsScreen(
            initialMine: true,
            session: const UserSession(
              id: '1',
              name: 'Test',
              number: '9999999999',
            ),
            reportService: ReportsFixtureService(),
          ),
          'mr',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('माझे अहवाल'), findsNWidgets(2));
      expect(find.text('अहवाल PDF'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'pothole');
      await tester.pumpAndSettle();
      expect(find.text('अहवाल PDF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
