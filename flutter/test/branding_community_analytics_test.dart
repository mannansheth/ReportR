import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/app.dart';
import 'package:reportr_flutter/main.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/l10n/app_localizations.dart';
import 'package:reportr_flutter/l10n/ui_strings.dart';
import 'package:reportr_flutter/models/community_analytics.dart';
import 'package:reportr_flutter/models/user_session.dart';
import 'package:reportr_flutter/screens/analytics/analytics_screen.dart';
import 'package:reportr_flutter/services/analytics_service.dart';
import 'package:reportr_flutter/widgets/brand.dart';

class FakeAnalytics extends AnalyticsService {
  FakeAnalytics() : super(ApiClient());
  final scopes = <String>[];
  @override
  Future<CommunityAnalytics> load({required String scope}) async {
    scopes.add(scope);
    return CommunityAnalytics.fromJson({
      'scope': scope,
      'total': scope == 'community' ? 12 : 0,
      'resolved': scope == 'community' ? 3 : 0,
      'active': scope == 'community' ? 8 : 0,
      'invalid': scope == 'community' ? 1 : 0,
      'pending': 2,
      'confirmationCount': scope == 'community' ? 9 : 0,
      'byStatus': [
        {'status': 'Resolved', 'count': 3},
      ],
      'byCategory': [
        {'category': 'Pothole', 'count': 8},
      ],
      'byPriority': [
        {'priority': 'High', 'count': 4},
      ],
      'monthly': [
        {'month': '2026-10', 'count': 12, 'resolved': 3},
      ],
      'averageResolutionHours': 24.5,
    });
  }
}

Widget wrap(String locale, Widget body) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: body),
);
void main() {
  test('Flutter logo is the original frontend asset without modification', () {
    expect(
      File('assets/branding/logo.png').readAsBytesSync(),
      File('../frontend/assets/logo.png').readAsBytesSync(),
    );
  });
  testWidgets(
    'startup shows original logo and original style loader before initialization completes',
    (tester) async {
      final pending = Completer<AppController>();
      await tester.pumpWidget(
        ReportRBootstrap(initialize: () => pending.future),
      );
      await tester.pump();
      expect(find.byType(ReportRLogo), findsOneWidget);
      expect(find.byType(ReportRLoader), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, ReportRLogo.asset);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'new user sees community totals first and can switch to empty personal scope',
    (tester) async {
      final service = FakeAnalytics();
      await tester.pumpWidget(
        wrap(
          'en',
          AnalyticsScreen(
            session: const UserSession(
              id: 'new',
              name: 'New User',
              number: '9998887777',
            ),
            analyticsService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.scopes, ['community']);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Community impact'), findsOneWidget);
      await tester.tap(find.text('My impact'));
      await tester.pumpAndSettle();
      expect(service.scopes, ['community', 'mine']);
      expect(
        find.text(
          'You have not submitted a report yet. Switch to Community to explore local progress.',
        ),
        findsOneWidget,
      );
      expect(find.text('12'), findsNothing);
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();
      expect(find.text('12'), findsOneWidget);
    },
  );
  testWidgets('community scope selector localizes into Hindi and Marathi', (
    tester,
  ) async {
    for (final locale in ['hi', 'mr']) {
      final ui = UiStrings(locale);
      await tester.pumpWidget(
        wrap(
          locale,
          AnalyticsScreen(
            key: ValueKey(locale),
            session: null,
            analyticsService: FakeAnalytics(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ui.text('Community impact')), findsOneWidget);
      expect(find.text(ui.text('Community')), findsOneWidget);
      expect(find.text('Community'), findsNothing);
    }
  });
}
