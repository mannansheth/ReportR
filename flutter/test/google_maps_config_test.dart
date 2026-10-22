import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reportr_flutter/screens/map/map_screen.dart';
import 'package:reportr_flutter/services/google_maps_config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GoogleMapsConfigService.channel, null);
  });

  test('reads native key configuration without exposing a key', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GoogleMapsConfigService.channel, (
          call,
        ) async {
          expect(call.method, 'isConfigured');
          return false;
        });
    expect(await const GoogleMapsConfigService().isConfigured(), false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          GoogleMapsConfigService.channel,
          (_) async => true,
        );
    expect(await const GoogleMapsConfigService().isConfigured(), true);
  });

  test('native configuration failure safely disables platform map', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          GoogleMapsConfigService.channel,
          (_) async =>
              throw PlatformException(code: 'configuration_unavailable'),
        );
    expect(await const GoogleMapsConfigService().isConfigured(), false);
  });

  testWidgets(
    'missing key shows report fallback and never constructs GoogleMap',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            GoogleMapsConfigService.channel,
            (_) async => false,
          );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MapScreen(isActive: false))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GoogleMap), findsNothing);
      expect(find.text('Map preview unavailable'), findsOneWidget);
      expect(
        find.text(
          'Google Maps is not configured yet. Browse reports and their locations below.',
        ),
        findsOneWidget,
      );
      expect(find.text('No reports match this filter.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
