import 'report_analytics.dart';

class CommunityAnalytics {
  const CommunityAnalytics({
    required this.scope,
    required this.total,
    required this.resolved,
    required this.active,
    required this.pending,
    required this.invalid,
    required this.confirmationCount,
    required this.byStatus,
    required this.byCategory,
    required this.byPriority,
    required this.monthly,
    this.averageResolutionHours,
    this.resolvedWithEvidence = 0,
  });
  final String scope;
  final int total, resolved, active, pending, invalid, confirmationCount;
  final Map<String, int> byStatus, byCategory, byPriority;
  final List<AnalyticsMonth> monthly;
  final double? averageResolutionHours;
  final int resolvedWithEvidence;
  double get resolutionRate => total == 0 ? 0 : resolved / total;
  factory CommunityAnalytics.fromJson(Map<String, dynamic> json) {
    int count(dynamic value) =>
        value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    Map<String, int> breakdown(String key, String label) => {
      for (final row in (json[key] as List? ?? const []))
        if (row is Map)
          (row[label]?.toString() ?? 'Unknown'): count(row['count']),
    };
    return CommunityAnalytics(
      scope: json['scope']?.toString() ?? 'community',
      total: count(json['total']),
      resolved: count(json['resolved']),
      active: count(json['active']),
      pending: count(json['pending']),
      invalid: count(json['invalid']),
      confirmationCount: count(json['confirmationCount']),
      resolvedWithEvidence: count(json['resolvedWithEvidence']),
      byStatus: breakdown('byStatus', 'status'),
      byCategory: breakdown('byCategory', 'category'),
      byPriority: breakdown('byPriority', 'priority'),
      monthly: [
        for (final row in (json['monthly'] as List? ?? const []))
          if (row is Map)
            AnalyticsMonth(
              row['month'].toString(),
              count(row['count']),
              count(row['resolved']),
            ),
      ],
      averageResolutionHours: json['averageResolutionHours'] == null
          ? null
          : double.tryParse('${json['averageResolutionHours']}'),
    );
  }
  factory CommunityAnalytics.fromReports(ReportAnalytics data) =>
      CommunityAnalytics(
        scope: 'mine',
        total: data.total,
        resolved: data.resolved,
        active: data.active,
        pending: data.statuses['Verification pending'] ?? 0,
        invalid: data.invalid,
        confirmationCount: 0,
        byStatus: data.statuses,
        byCategory: data.categories,
        byPriority: const {},
        monthly: data.monthly.entries
            .map(
              (e) => AnalyticsMonth(
                '${e.key.year}-${e.key.month.toString().padLeft(2, '0')}',
                e.value,
                0,
              ),
            )
            .toList(),
      );
}

class AnalyticsMonth {
  const AnalyticsMonth(this.month, this.count, this.resolved);
  final String month;
  final int count, resolved;
  DateTime? get date => DateTime.tryParse('$month-01');
}
