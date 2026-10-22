import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:reportr_flutter/models/prediction.dart';
import 'package:reportr_flutter/models/report_location.dart';
import 'package:reportr_flutter/services/exif_service.dart';
import 'package:reportr_flutter/widgets/prediction_image_overlay.dart';

void main() {
  test('predictions parse and sort by probability descending', () {
    final predictions = Prediction.parseList([
      {
        'issue': 'Garbage',
        'probability': 0.2,
        'description': 'Overflowing bin',
        'bounding_box': [100, 200, 300, 400],
      },
      {
        'issue': 'Pothole',
        'probability': 0.9,
        'description': 'Road damage',
        'bounding_box': [1, 2, 3, 4],
      },
    ]);

    expect(predictions.map((item) => item.issue), ['Pothole', 'Garbage']);
    expect(predictions.first.boundingBox, [1, 2, 3, 4]);
  });

  test('malformed prediction responses are rejected', () {
    expect(
      () => Prediction.parseList([
        {'issue': 'Pothole', 'probability': 0.9},
      ]),
      throwsFormatException,
    );
    expect(() => Prediction.parseList({'data': []}), throwsFormatException);
  });

  test('bounding boxes account for the BoxFit.cover image rectangle', () {
    final imageRect = displayedImageRect(const Size(400, 300), const Size(1000, 1000));
    expect(imageRect, const Rect.fromLTRB(0, -50, 400, 350));

    final box = boundingBoxRect([100, 200, 500, 800], imageRect);
    expect(box, const Rect.fromLTRB(80, -10, 320, 150));
  });
  test('EXIF DMS conversion applies west and south references', () {
    expect(
      ExifService.dmsToDecimal(
        degrees: 19,
        minutes: 2,
        seconds: 24,
        reference: 'N',
      ),
      closeTo(19.04, 0.000001),
    );
    expect(
      ExifService.dmsToDecimal(
        degrees: 72,
        minutes: 52,
        seconds: 12,
        reference: 'W',
      ),
      closeTo(-72.87, 0.000001),
    );
  });

  test('location serializes with prediction/report-compatible keys', () {
    const location = ReportLocation(
      latitude: 19.04,
      longitude: 72.87,
      readableLocation: 'Name, Street, City, Region, 400001, India',
    );
    expect(location.toJson(), {
      'lat': 19.04,
      'lng': 72.87,
      'loc': 'Name, Street, City, Region, 400001, India',
    });
  });


}
