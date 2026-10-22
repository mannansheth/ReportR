import '../core/network/api_client.dart';
import '../models/map_report.dart';

class MapService {
  const MapService(this._client);
  final ApiClient _client;

  Future<List<MapReportMarker>> getAllReports() async {
    final response = await _client.getJson('api/reports/getAllReports');
    _checkResponse(response);
    return MapReportMarker.parseList(response);
  }

  Future<List<Map<String, dynamic>>> getReportsByLocation({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.postJsonValue(
      'api/reports/getReportByLocation',
      {'lat': latitude, 'lng': longitude},
    );
    _checkResponse(response);
    if (response is! List) {
      throw const FormatException('Invalid nearby report response');
    }
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<MapReportDetails> getReportDetails({
    required String reportId,
    required bool canResolve,
  }) async {
    final response = await _client.postJsonValue(
      'api/reports/getPublicReportData',
      {'Rid': reportId},
    );
    _checkResponse(response);
    if (response is! Map) {
      throw const FormatException('Invalid report detail response');
    }
    return MapReportDetails.fromJson(
      Map<String, dynamic>.from(response),
      canResolve: canResolve,
    );
  }

  static void _checkResponse(dynamic response) {
    if (response is Map && response['success'] == false) {
      throw ApiClientException(
        response['message']?.toString() ?? 'Unable to load map reports.',
      );
    }
  }
}
