import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../core/network/api_client.dart';
import '../models/community_report.dart';

class CommunityPosition {
  const CommunityPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
  final double latitude, longitude, accuracy;
  final DateTime timestamp;
  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}

class CommunityLocationService {
  Future<CommunityPosition> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiClientException('Enable location services to continue.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiClientException(
        'Location permission is required for community actions.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (position.accuracy < 0 ||
        position.accuracy > 100 ||
        DateTime.now().difference(position.timestamp).inSeconds.abs() > 300) {
      throw const ApiClientException(
        'A more accurate, fresh location is needed. Move outdoors and try again.',
      );
    }
    return CommunityPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}

class CommunityService {
  const CommunityService(this.client);
  final ApiClient client;
  Future<CommunityPage> getReports({
    int page = 1,
    String sort = 'priority',
    CommunityPosition? location,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'limit': '20',
        'sort': sort,
        if (location != null) ...{
          'lat': '${location.latitude}',
          'lng': '${location.longitude}',
        },
      },
    ).query;
    final response = await client.getJson('api/reports/community?$query');
    return CommunityPage.fromJson(_map(response));
  }

  Future<CommunityReport> getReport(String id) async => _report(
    await client.getJson('api/reports/community/${Uri.encodeComponent(id)}'),
  );
  Future<CommunityReport> confirm(
    String id,
    CommunityPosition location,
  ) async => _report(
    await client.postJsonValue(
      'api/reports/${Uri.encodeComponent(id)}/confirm',
      {'location': location.toJson()},
    ),
  );
  Future<CommunityReport> resolve(
    String id,
    CommunityPosition location, {
    String note = '',
    String? imagePath,
  }) async {
    final fields = <String, dynamic>{
      'location': jsonEncode(location.toJson()),
      'note': note,
    };
    if (imagePath != null) {
      final file = await File(imagePath).open();
      late final List<int> header;
      try {
        header = await file.read(12);
      } finally {
        await file.close();
      }
      final subtype =
          header.length >= 3 && header[0] == 0xff && header[1] == 0xd8
          ? 'jpeg'
          : header.length >= 8 &&
                header[0] == 0x89 &&
                header[1] == 0x50 &&
                header[2] == 0x4e &&
                header[3] == 0x47
          ? 'png'
          : header.length >= 12 &&
                String.fromCharCodes(header.take(4)) == 'RIFF' &&
                String.fromCharCodes(header.skip(8).take(4)) == 'WEBP'
          ? 'webp'
          : null;
      if (subtype == null) {
        throw const ApiClientException(
          'Choose a JPEG, PNG or WebP photo for evidence.',
        );
      }
      fields['image'] = await MultipartFile.fromFile(
        imagePath,
        filename: 'resolution.$subtype',
        contentType: DioMediaType('image', subtype),
      );
    }
    return _report(
      await client.postMultipart(
        'api/reports/${Uri.encodeComponent(id)}/resolution',
        FormData.fromMap(fields),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic response) {
    if (response is! Map) {
      throw const ApiClientException('Unable to load community reports.');
    }
    if (response['success'] == false) {
      throw ApiClientException(
        response['message']?.toString() ??
            'Community action could not be completed.',
      );
    }
    return Map<String, dynamic>.from(response);
  }

  static CommunityReport _report(dynamic response) {
    final envelope = _map(response);
    if (envelope['report'] is! Map) {
      throw const ApiClientException('Unable to load community report.');
    }
    return CommunityReport.fromJson(
      Map<String, dynamic>.from(envelope['report'] as Map),
    );
  }
}
