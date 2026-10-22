import 'dart:convert';

/// Deliberately excludes identities, contact details, audio and private PDFs.
class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.issue,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.locationName = '',
    this.imageUrl,
    this.priority = 0,
    this.baselinePriority = 0,
    this.confirmationCount = 0,
    this.confirmedByMe = false,
    this.isOwner = false,
    this.distanceMeters,
    this.resolutionWeight = 0,
    this.resolutionVoters = 0,
    this.resolvedAt,
    this.resolutionVotedByMe = false,
    this.myEvidenceState = 'none',
    this.resolutionOriginalReporterVoted = false,
    this.resolutionVerifiedPhoto = false,
  });
  final String id, issue, description, status, createdAt, locationName;
  final double latitude,
      longitude,
      priority,
      baselinePriority,
      resolutionWeight;
  final int confirmationCount, resolutionVoters;
  final bool confirmedByMe, isOwner;
  final double? distanceMeters;
  final String? imageUrl, resolvedAt;
  final bool resolutionVotedByMe,
      resolutionOriginalReporterVoted,
      resolutionVerifiedPhoto;
  final String myEvidenceState;

  factory CommunityReport.fromJson(Map<String, dynamic> json) {
    final raw = json['location'];
    final location = raw is String ? jsonDecode(raw) : raw;
    if (json['Rid'] == null || location is! Map) {
      throw const FormatException('Invalid community report');
    }
    final lat = double.tryParse(location['lat']?.toString() ?? '');
    final lng = double.tryParse(location['lng']?.toString() ?? '');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      throw const FormatException('Invalid community location');
    }
    double number(String key) =>
        double.tryParse(json[key]?.toString() ?? '') ?? 0;
    return CommunityReport(
      id: json['Rid'].toString(),
      issue: json['issue']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      latitude: lat,
      longitude: lng,
      locationName: location['loc']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Issue Raised',
      createdAt: json['createdAt']?.toString() ?? '',
      imageUrl: json['imageURL']?.toString(),
      priority: number('priority'),
      baselinePriority: number('baselinePriority'),
      confirmationCount: number('confirmationCount').toInt(),
      confirmedByMe: json['confirmedByMe'] == true,
      isOwner: json['isOwner'] == true,
      distanceMeters: double.tryParse(json['distanceMeters']?.toString() ?? ''),
      resolutionWeight: number('resolutionWeight'),
      resolutionVoters: number('resolutionVoters').toInt(),
      resolvedAt: json['resolvedAt']?.toString(),
      resolutionVotedByMe: json['resolutionVotedByMe'] == true,
      myEvidenceState: json['myEvidenceState']?.toString() ?? 'none',
      resolutionOriginalReporterVoted:
          json['resolutionOriginalReporterVoted'] == true,
      resolutionVerifiedPhoto: json['resolutionVerifiedPhoto'] == true,
    );
  }
  bool get isResolved => status == 'Resolved';
  bool get isOpen => !isResolved && status != 'Invalid Report';
  double get resolutionProgress => (resolutionWeight / 5).clamp(0, 1);
}

class CommunityPage {
  const CommunityPage({
    required this.reports,
    required this.total,
    required this.page,
    required this.hasMore,
  });
  final List<CommunityReport> reports;
  final int total, page;
  final bool hasMore;
  factory CommunityPage.fromJson(Map<String, dynamic> json) {
    if (json['reports'] is! List) {
      throw const FormatException('Invalid community feed');
    }
    return CommunityPage(
      reports: (json['reports'] as List)
          .map(
            (row) =>
                CommunityReport.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasMore: json['hasMore'] == true,
    );
  }
}

class CommunityRange {
  static bool canConfirm(double meters) =>
      meters.isFinite && meters >= 0 && meters <= 500;
  static bool canResolve(double meters) =>
      meters.isFinite && meters >= 0 && meters <= 200;
}
