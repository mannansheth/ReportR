import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/models/report_analytics.dart';
import 'package:reportr_flutter/models/report_record.dart';

ReportRecord report(String status, String date, {String issue = 'Pothole'}) =>
    ReportRecord(
      id: date,
      userId: '1',
      issue: issue,
      description: '',
      location: const {},
      createdAt: date,
      status: status,
    );

void main() {
  test('real status counts include invalid reports in submitted total', () {
    final analytics = ReportAnalytics([
      report('Resolved', '2026-10-01'),
      report('Invalid Report', '2026-10-02'),
      report('In Progress', '2026-10-03'),
      report('Verification pending', '2026-10-04', issue: 'Garbage'),
    ]);
    expect(analytics.total, 4);
    expect(analytics.resolved, 1);
    expect(analytics.active, 2);
    expect(analytics.invalid, 1);
    expect(analytics.resolutionRate, .25);
    expect(analytics.categories['Pothole'], 3);
  });
  test(
    'six month activity crosses years and excludes malformed or old dates',
    () {
      final analytics = ReportAnalytics([
        report('Resolved', '2025-12-31T18:00:00Z'),
        report('Resolved', '2026-01-03'),
        report('Resolved', '2025-07-01'),
        report('Resolved', 'invalid'),
      ], now: DateTime(2026, 1, 14));
      expect(analytics.monthly.keys.first, DateTime(2025, 8));
      expect(analytics.monthly[DateTime(2025, 12)], 1);
      expect(analytics.monthly[DateTime(2026, 1)], 1);
      expect(analytics.monthly.values.reduce((a, b) => a + b), 2);
    },
  );
  test('empty account has zero resolution rate and zero month counts', () {
    final analytics = ReportAnalytics([]);
    expect(analytics.resolutionRate, 0);
    expect(analytics.active, 0);
    expect(analytics.monthly.length, 6);
  });
}
