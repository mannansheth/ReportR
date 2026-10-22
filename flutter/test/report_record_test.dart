import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/models/report_record.dart';

void main() {
  test('report accepts SQL JSON string and string coordinates', () {
    final report = ReportRecord.fromJson({
      'Rid': 'r1',
      'issue': 'Drainage',
      'location': '{"lat":"19.1","lng":"72.8","loc":"Mumbai"}',
      'resolutionNote': 'Drain cleared',
      'resolvedBy': 'Ward officer',
    });
    expect(report.latitude, 19.1);
    expect(report.longitude, 72.8);
    expect(report.resolutionNote, 'Drain cleared');
    expect(report.resolvedBy, 'Ward officer');
  });
  test('report record parses existing backend fields and location', () {
    final report = ReportRecord.fromJson({
      'Rid': 'Rid_test',
      'userID': 23,
      'issue': 'Pothole',
      'description': 'Road damage',
      'location': {'lat': 19.1, 'lng': 72.8, 'loc': 'Mumbai'},
      'createdAt': '2026-10-01 12:00:00',
      'status': 'Issue Raised',
      'priority': '7',
      'imageURL': 'https://example.com/image.jpg',
    });

    expect(report.id, 'Rid_test');
    expect(report.userId, '23');
    expect(report.readableLocation, 'Mumbai');
    expect(report.latitude, 19.1);
    expect(report.imageUrl, 'https://example.com/image.jpg');
  });

  test('status history parses lifecycle events', () {
    final event = ReportStatusEvent.fromJson({
      'id': 1,
      'Rid': 'Rid_test',
      'previousStatus': 'Issue Raised',
      'newStatus': 'Verification pending',
      'changedAt': '2026-10-01 12:00:00',
      'source': 'system',
    });

    expect(event.previousStatus, 'Issue Raised');
    expect(event.newStatus, 'Verification pending');
    expect(event.changedAt, '2026-10-01 12:00:00');
  });
  test('malformed report responses are rejected', () {
    expect(
      () => ReportRecord.parseList([
        {'Rid': 'Rid_test', 'issue': 'Pothole'},
      ]),
      throwsFormatException,
    );
  });
}
