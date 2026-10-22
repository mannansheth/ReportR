import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:reportr_flutter/models/media_asset.dart';
import 'package:reportr_flutter/models/prediction.dart';
import 'package:reportr_flutter/screens/home/report_form_screen.dart';
import 'package:reportr_flutter/widgets/prediction_image_overlay.dart';
import 'package:reportr_flutter/screens/map/map_screen.dart';
import 'package:reportr_flutter/services/google_maps_config_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('phone: missing Google Maps key avoids native SDK creation', (
    tester,
  ) async {
    expect(await const GoogleMapsConfigService().isConfigured(), isFalse);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MapScreen(isActive: false))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.text('Map preview unavailable'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'phone: full image, every box, unique multi-select, collapse and expand',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await PreferencesService.create();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1200, 800),
        Paint()..color = const Color(0xFF596A73),
      );
      canvas.drawRect(
        const Rect.fromLTWH(20, 20, 1160, 120),
        Paint()..color = const Color(0xFFBDD5A0),
      );
      canvas.drawOval(
        const Rect.fromLTWH(140, 330, 270, 160),
        Paint()..color = const Color(0xFF192027),
      );
      canvas.drawOval(
        const Rect.fromLTWH(650, 490, 340, 210),
        Paint()..color = const Color(0xFF192027),
      );
      canvas.drawRect(
        const Rect.fromLTWH(840, 170, 210, 190),
        Paint()..color = const Color(0xFFE3C285),
      );
      final image = await recorder.endRecording().toImage(1200, 800);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File(
        '${(await getTemporaryDirectory()).path}/prediction-review-fixture.png',
      );
      await file.writeAsBytes(data!.buffer.asUint8List());
      final predictions = [
        const Prediction(
          issue: 'Pothole',
          probability: .94,
          description: 'Road damage',
          boundingBox: [412, 116, 612, 342],
        ),
        const Prediction(
          issue: ' pothole ',
          probability: .81,
          description: 'Another pothole',
          boundingBox: [612, 541, 875, 825],
        ),
        const Prediction(
          issue: 'Garbage overflow',
          probability: .88,
          description: 'Garbage',
          boundingBox: [212, 700, 450, 875],
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: ReportFormScreen(
            session: null,
            preferences: preferences,
            location: null,
            predictions: predictions,
            image: MediaAsset(
              path: file.path,
              base64: base64Encode(await file.readAsBytes()),
              mimeType: 'image/png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pothole'), findsOneWidget);
      expect(find.text('Garbage overflow'), findsOneWidget);
      expect(find.text('Road damage'), findsNothing);
      expect(find.text('Continue with 2 issues'), findsOneWidget);
      expect(
        tester
            .widget<PredictionImageOverlay>(find.byType(PredictionImageOverlay))
            .predictions
            .length,
        3,
      );
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('prediction-fullscreen');
      await tester.tap(find.text('Garbage overflow'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with 1 issue'), findsOneWidget);
      await tester.tap(find.text('Garbage overflow'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with 2 issues'));
      await tester.pumpAndSettle();
      expect(find.text('Report details'), findsOneWidget);
      expect(find.text('Pothole'), findsOneWidget);
      expect(find.text('Garbage overflow'), findsOneWidget);
      await binding.takeScreenshot('prediction-collapsed-details');
      await tester.tap(find.text('Review photo'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with 2 issues'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await file.delete();
    },
  );
}
