import 'dart:convert';

class ReportRecord {
  const ReportRecord({
    required this.id,
    required this.userId,
    required this.issue,
    required this.description,
    required this.location,
    required this.createdAt,
    required this.status,
    this.priority,
    this.imageUrl,
    this.audioUrl,
    this.pdfUrl,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String userId;
  final String issue;
  final String description;
  final Map<String, dynamic> location;
  final String createdAt;
  final String status;
  final String? priority;
  final String? imageUrl;
  final String? audioUrl;
  final String? pdfUrl;
  final String? resolutionNote;
  final String? resolvedAt;
  final String? resolvedBy;

  factory ReportRecord.fromJson(Map<String, dynamic> json) {
    final rawLocation = json['location'];
    final location = rawLocation is String
        ? jsonDecode(rawLocation)
        : rawLocation;
    if (json['Rid'] == null || json['issue'] is! String || location is! Map) {
      throw const FormatException('Invalid report response');
    }
    return ReportRecord(
      id: json['Rid'].toString(),
      userId: json['userID']?.toString() ?? '',
      issue: json['issue'] as String,
      description: json['description']?.toString() ?? '',
      location: Map<String, dynamic>.from(location),
      createdAt: json['createdAt']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Unknown',
      priority: json['priority']?.toString(),
      imageUrl: _optionalString(json['imageURL']),
      audioUrl: _optionalString(json['audioURL']),
      pdfUrl: _optionalString(json['pdfURL']),
      resolutionNote: _optionalString(json['resolutionNote']),
      resolvedAt: _optionalString(json['resolvedAt']),
      resolvedBy: _optionalString(json['resolvedBy']),
    );
  }

  static String? _optionalString(dynamic value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  static List<ReportRecord> parseList(dynamic value) {
    if (value is! List) throw const FormatException('Reports are not an array');
    return value
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid report response');
          }
          return ReportRecord.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  String get readableLocation => location['loc']?.toString() ?? '';
  double? get latitude => double.tryParse(location['lat']?.toString() ?? '');
  double? get longitude => double.tryParse(location['lng']?.toString() ?? '');
}

class ReportStatusEvent {
  const ReportStatusEvent({
    required this.id,
    required this.reportId,
    required this.previousStatus,
    required this.newStatus,
    required this.changedAt,
    required this.source,
  });

  final int id;
  final String reportId;
  final String? previousStatus;
  final String newStatus;
  final String changedAt;
  final String source;

  factory ReportStatusEvent.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! num ||
        json['Rid'] == null ||
        json['newStatus'] is! String) {
      throw const FormatException('Invalid report status event');
    }
    return ReportStatusEvent(
      id: (json['id'] as num).toInt(),
      reportId: json['Rid'].toString(),
      previousStatus: json['previousStatus']?.toString(),
      newStatus: json['newStatus'] as String,
      changedAt: json['changedAt']?.toString() ?? '',
      source: json['source']?.toString() ?? 'system',
    );
  }

  static List<ReportStatusEvent> parseList(dynamic value) {
    if (value is! List) {
      throw const FormatException('Status history is not an array');
    }
    return value
        .map(
          (item) => ReportStatusEvent.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }
}
