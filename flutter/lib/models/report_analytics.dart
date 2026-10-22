import 'report_record.dart';

class ReportAnalytics {
  ReportAnalytics(this.reports, {DateTime? now}) : now = now ?? DateTime.now();
  final List<ReportRecord> reports;
  final DateTime now;
  int get total => reports.length;
  int get resolved => reports.where((r) => r.status == 'Resolved').length;
  int get invalid => reports.where((r) => r.status == 'Invalid Report').length;
  int get active => total - resolved - invalid;
  double get resolutionRate => total == 0 ? 0 : resolved / total;
  Map<String, int> get statuses {
    final counts = <String, int>{};
    for (final report in reports) {
      counts.update(report.status, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, int> get categories {
    final counts = <String, int>{};
    for (final report in reports) {
      counts.update(report.issue, (v) => v + 1, ifAbsent: () => 1);
    }
    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  Map<DateTime, int> get monthly {
    final counts = <DateTime, int>{
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i): 0,
    };
    for (final report in reports) {
      final date = DateTime.tryParse(report.createdAt);
      if (date == null) continue;
      final month = DateTime(date.year, date.month);
      if (counts.containsKey(month)) counts[month] = counts[month]! + 1;
    }
    return counts;
  }
}
