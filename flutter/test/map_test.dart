import 'package:flutter_test/flutter_test.dart';

import 'package:reportr_flutter/models/map_report.dart';
import 'package:reportr_flutter/services/map_distance_service.dart';

void main() {
  test(
    'native markers accept decimal coordinates and reject invalid ranges',
    () {
      final marker = MapReportMarker.fromJson({
        'Rid': 'native',
        'issue': 'Pothole',
        'lat': '19.1',
        'lng': '72.8',
        'status': 'Resolved',
      });
      expect(marker.latitude, 19.1);
      expect(marker.issue, 'Pothole');
      expect(marker.markerHue, 120);
      expect(
        () => MapReportMarker.fromJson({'Rid': 'bad', 'lat': 91, 'lng': 0}),
        throwsFormatException,
      );
      expect(
        () => MapReportMarker.fromJson({'Rid': 'bad', 'lat': 0, 'lng': 'NaN'}),
        throwsFormatException,
      );
    },
  );
  test('parses backend marker payload and preserves report identifiers', () {
    final marker = MapReportMarker.fromJson({
      'Rid': 'Rid_202501ab',
      'lat': 19.1,
      'lng': 72.8,
      'status': 'Resolved',
      'color': 'green',
      'userID': 7,
    });

    expect(marker.id, 'Rid_202501ab');
    expect(marker.userId, 7);
    expect(marker.toJson()['Rid'], 'Rid_202501ab');
    expect(marker.toJson()['lat'], 19.1);
  });

  test('filters invalid reports and supports status and owner filters', () {
    final markers = [
      MapReportMarker.fromJson({
        'Rid': 'a',
        'lat': 1,
        'lng': 2,
        'status': 'Resolved',
        'userID': 'u1',
      }),
      MapReportMarker.fromJson({
        'Rid': 'b',
        'lat': 1,
        'lng': 2,
        'status': 'Invalid Report',
        'userID': 'u1',
      }),
      MapReportMarker.fromJson({
        'Rid': 'c',
        'lat': 1,
        'lng': 2,
        'status': 'In Progress',
        'userID': 'u2',
      }),
    ];

    expect(MapReportMarker.visibleFor(markers).map((m) => m.id), ['a', 'c']);
    expect(
      MapReportMarker.visibleFor(
        markers,
        filter: 'My reports',
        userId: 'u1',
      ).map((m) => m.id),
      ['a', 'b'],
    );
    expect(
      MapReportMarker.visibleFor(markers, filter: 'Resolved').map((m) => m.id),
      ['a'],
    );
  });

  test('uses the Haversine distance in meters for the 200m rule', () {
    expect(MapDistance.meters(19, 72, 19, 72), 0);
    expect(MapDistance.meters(19, 72, 19.001, 72), closeTo(111.2, 1));
    expect(MapDistance.meters(19, 72, 19.001, 72) < 200, isTrue);
  });
}
