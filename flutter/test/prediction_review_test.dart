import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/models/prediction.dart';
import 'package:reportr_flutter/widgets/prediction_image_overlay.dart';
import 'package:reportr_flutter/widgets/prediction_options.dart';

const detections = [
  Prediction(
    issue: 'Pothole',
    probability: .92,
    description: 'Road damage',
    boundingBox: [100, 100, 300, 400],
  ),
  Prediction(
    issue: ' pothole ',
    probability: .65,
    description: 'Another damaged patch',
    boundingBox: [500, 600, 900, 950],
  ),
  Prediction(
    issue: 'Garbage overflow',
    probability: .8,
    description: 'Trash',
    boundingBox: [50, 500, 200, 900],
  ),
];

void main() {
  test('duplicate titles produce one category and retain every object box', () {
    final unique = Prediction.uniqueIssues(detections);
    expect(unique.length, 2);
    expect(unique.first.probability, .92);
    expect(unique.map((p) => p.issueKey), ['pothole', 'garbage overflow']);
    expect(detections.length, 3);
  });

  test(
    'contain keeps the full landscape image visible on a portrait screen',
    () {
      final rect = displayedImageRect(
        const Size(360, 740),
        const Size(1200, 800),
        fit: BoxFit.contain,
      );
      expect(rect, const Rect.fromLTWH(0, 250, 360, 240));
      expect(boundingBoxRect([0, 0, 1000, 1000], rect), rect);
      expect(
        boundingBoxRect([500, 500, 1000, 1000], rect),
        const Rect.fromLTWH(180, 370, 180, 120),
      );
    },
  );

  test('reversed corners normalize and invalid boxes disappear', () {
    const rect = Rect.fromLTWH(0, 0, 400, 300);
    expect(boundingBoxRect([1200, 1000, -20, 0], rect), rect);
    expect(boundingBoxRect([double.nan, 0, 1, 1], rect), Rect.zero);
  });

  testWidgets('floating options deduplicate and allow multiple selections', (
    tester,
  ) async {
    var selected = <String>{'pothole'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PredictionOptions(
                predictions: detections,
                selectedIssues: selected,
                dark: false,
                onToggle: (key) {
                  setState(
                    () => selected = selected.contains(key)
                        ? (Set.of(selected)..remove(key))
                        : (Set.of(selected)..add(key)),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('Pothole'), findsOneWidget);
    expect(find.text('pothole'), findsNothing);
    expect(find.text('Road damage'), findsNothing);
    expect(find.text('Trash'), findsNothing);
    await tester.tap(find.text('Garbage overflow'));
    await tester.pump();
    expect(selected, {'pothole', 'garbage overflow'});
    await tester.tap(find.text('Pothole'));
    await tester.pump();
    expect(selected, {'garbage overflow'});
    expect(tester.takeException(), isNull);
  });
}
