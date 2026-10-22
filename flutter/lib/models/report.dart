import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'report_location.dart';

class ReportIdGenerator {
  const ReportIdGenerator._();

  static String generate({DateTime? now, String? uuid}) {
    final year = (now ?? DateTime.now()).year;
    final compactUuid = (uuid ?? const Uuid().v4()).replaceAll('-', '');
    if (compactUuid.length < 12) {
      throw const FormatException(
        'UUID must contain at least twelve characters.',
      );
    }
    return 'Rid_$year${compactUuid.substring(0, 12)}';
  }
}

class ReportDraft {
  const ReportDraft({
    required this.reportID,
    required this.userID,
    required this.name,
    required this.number,
    required this.category,
    required this.description,
    required this.location,
    required this.createdDate,
    this.imagePath,
    this.audioPath,
  });

  final String reportID;
  final String userID;
  final String name;
  final String number;
  final String category;
  final String description;
  final ReportLocation location;
  final String createdDate;
  final String? imagePath;
  final String? audioPath;

  Map<String, dynamic> toJson() => {
    'reportID': reportID,
    'userID': userID,
    'name': name,
    'number': number,
    'category': category,
    'description': description,
    'location': location.toJson(),
    'createdDate': createdDate,
    if (imagePath != null) 'imagePath': imagePath,
    if (audioPath != null) 'audioPath': audioPath,
  };

  String toJsonString() => jsonEncode(toJson());

  factory ReportDraft.fromJson(Map<String, dynamic> json) {
    final rawLocation = json['location'];
    if (json['reportID'] is! String ||
        json['userID'] is! String ||
        json['name'] is! String ||
        json['number'] is! String ||
        json['category'] is! String ||
        json['description'] is! String ||
        json['createdDate'] is! String ||
        rawLocation is! Map) {
      throw const FormatException('Invalid report draft');
    }
    final location = Map<String, dynamic>.from(rawLocation);
    if (location['lat'] is! num ||
        location['lng'] is! num ||
        location['loc'] is! String) {
      throw const FormatException('Invalid report location');
    }
    return ReportDraft(
      reportID: json['reportID'] as String,
      userID: json['userID'] as String,
      name: json['name'] as String,
      number: json['number'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      location: ReportLocation(
        latitude: (location['lat'] as num).toDouble(),
        longitude: (location['lng'] as num).toDouble(),
        readableLocation: location['loc'] as String,
      ),
      createdDate: json['createdDate'] as String,
      imagePath: json['imagePath'] as String?,
      audioPath: json['audioPath'] as String?,
    );
  }
}
