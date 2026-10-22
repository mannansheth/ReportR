import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/services/community_service.dart';

class CommunityClient extends ApiClient {
  String? path;
  Map<String, dynamic>? body;
  FormData? multipart;
  @override
  Future<dynamic> getJson(String path) async {
    this.path = path;
    return {'reports': [], 'total': 0, 'page': 2, 'hasMore': false};
  }

  @override
  Future<dynamic> postJsonValue(String path, Map<String, dynamic> body) async {
    this.path = path;
    this.body = body;
    return {
      'report': {
        'Rid': 'r1',
        'location': {'lat': 0, 'lng': 0},
        'confirmedByMe': true,
        'confirmationCount': 2,
      },
    };
  }

  @override
  Future<dynamic> postMultipart(
    String path,
    FormData data, {
    Duration? receiveTimeout,
  }) async {
    this.path = path;
    multipart = data;
    return {
      'report': {
        'Rid': 'r1',
        'location': {'lat': 0, 'lng': 0},
        'resolutionWeight': 1,
      },
    };
  }
}

void main() {
  final position = CommunityPosition(
    latitude: 0,
    longitude: 0,
    accuracy: 8,
    timestamp: DateTime.utc(2026, 10, 15),
  );
  test('feed sends nearby sorting, coordinates and page', () async {
    final client = CommunityClient();
    await CommunityService(
      client,
    ).getReports(page: 2, sort: 'nearby', location: position);
    final query = Uri.parse(client.path!).queryParameters;
    expect(query['sort'], 'nearby');
    expect(query['page'], '2');
    expect(query['lat'], '0.0');
  });
  test(
    'confirmation sends location freshness proof and parses refreshed count',
    () async {
      final client = CommunityClient();
      final report = await CommunityService(client).confirm('r1', position);
      expect(client.path, 'api/reports/r1/confirm');
      expect(client.body?['location'], position.toJson());
      expect(report.confirmationCount, 2);
      expect(report.confirmedByMe, true);
    },
  );
  test('resolution photo uses detected MIME and includes note/GPS', () async {
    final directory = await Directory.systemTemp.createTemp('community-photo-');
    try {
      final photo = await File(
        '${directory.path}/camera.tmp',
      ).writeAsBytes([0xff, 0xd8, 0xff, 0xe0, 0, 1, 2]);
      final client = CommunityClient();
      await CommunityService(
        client,
      ).resolve('r1', position, note: 'Repaired', imagePath: photo.path);
      expect(
        client.multipart!.files.single.value.contentType.toString(),
        'image/jpeg',
      );
      expect(
        jsonDecode(
          client.multipart!.fields
              .firstWhere((field) => field.key == 'location')
              .value,
        ),
        position.toJson(),
      );
      expect(
        client.multipart!.fields
            .firstWhere((field) => field.key == 'note')
            .value,
        'Repaired',
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test(
    'unsupported evidence bytes are rejected before network upload',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'community-invalid-photo-',
      );
      try {
        final photo = await File(
          '${directory.path}/renamed.jpg',
        ).writeAsString('not an image');
        final client = CommunityClient();
        await expectLater(
          CommunityService(
            client,
          ).resolve('r1', position, imagePath: photo.path),
          throwsA(isA<ApiClientException>()),
        );
        expect(client.multipart, isNull);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
