import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:reportr_flutter/models/media_asset.dart';
import 'package:reportr_flutter/models/prediction.dart';
import 'package:reportr_flutter/screens/home/report_form_screen.dart';

void main() {
  testWidgets(
    'full image review deduplicates titles and preserves multi selection in form',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await PreferencesService.create();
      final directory = Directory.systemTemp.createTempSync(
        'reportr-selection',
      );
      final file = File('${directory.path}/image.png');
      const png =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=';
      file.writeAsBytesSync(base64Decode(png));
      addTearDown(() => directory.deleteSync(recursive: true));
      const predictions = [
        Prediction(
          issue: 'Pothole',
          probability: .9,
          description: 'Road damage',
          boundingBox: [0, 0, 400, 400],
        ),
        Prediction(
          issue: ' pothole ',
          probability: .8,
          description: 'Another hole',
          boundingBox: [500, 500, 900, 900],
        ),
        Prediction(
          issue: 'Garbage',
          probability: .7,
          description: 'Litter',
          boundingBox: [0, 500, 400, 900],
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: ReportFormScreen(
            session: null,
            preferences: preferences,
            image: MediaAsset(
              path: file.path,
              base64: png,
              mimeType: 'image/png',
            ),
            location: null,
            predictions: predictions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continue with 2 issues'), findsOneWidget);
      expect(find.text('Report details'), findsNothing);
      await tester.tap(find.text('Continue with 2 issues'));
      await tester.pumpAndSettle();
      expect(find.text('Report details'), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.length, 1);
      expect(fields.last.controller!.text, 'Road damage\nLitter');
      expect(find.text('Another hole'), findsNothing);
      await tester.ensureVisible(find.text('Garbage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garbage').last);
      await tester.pumpAndSettle();
      expect(fields.last.controller!.text, 'Road damage');
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.enterText(find.byType(TextField).last, 'My description');
      await tester.ensureVisible(find.text('Garbage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Garbage').last);
      await tester.pumpAndSettle();
      expect(fields.last.controller!.text, 'My description');
      await tester.scrollUntilVisible(
        find.text('Review photo'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review photo'));
      await tester.pumpAndSettle();
      expect(find.text('Continue with 2 issues'), findsOneWidget);
    },
  );
}
