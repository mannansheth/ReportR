import '../core/network/api_client.dart';
import '../models/report_record.dart';

class ReportService {
  const ReportService(this._client);
  final ApiClient _client;
  String? get authToken => _client.authToken;

  Future<List<ReportRecord>> getUserReports(String userId) async {
    final response = await _client.postJsonValue('api/reports/getUserReports', {
      'userID': userId,
    });
    if (response is Map && response['success'] == false) {
      throw ReportServiceException(
        response['message']?.toString() ?? 'Unable to load reports.',
      );
    }
    return ReportRecord.parseList(response);
  }

  Future<List<ReportStatusEvent>> getStatusHistory({
    required String reportId,
  }) async {
    final response = await _client.postJsonValue(
      'api/reports/getReportStatusHistory',
      {'Rid': reportId},
    );
    if (response is Map && response['success'] == false) {
      throw ReportServiceException(
        response['message']?.toString() ?? 'Unable to load report history.',
      );
    }
    return ReportStatusEvent.parseList(response);
  }

  Future<ReportRecord> getReportDetails({
    required String reportId,
    required String userId,
  }) async {
    final response = await _client.postJsonValue('api/reports/getReportData', {
      'Rid': reportId,
      'userID': userId,
    });
    if (response is Map && response['success'] == false) {
      throw ReportServiceException(
        response['message']?.toString() ?? 'Unable to load report.',
      );
    }
    if (response is! Map) {
      throw const FormatException('Invalid report detail response');
    }
    return ReportRecord.fromJson(Map<String, dynamic>.from(response));
  }
}

class ReportServiceException implements Exception {
  const ReportServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
