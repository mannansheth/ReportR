import '../core/network/api_client.dart';
import '../models/report_record.dart';

class AuthorityService {
  const AuthorityService(this._client);

  final ApiClient _client;
  String? get authToken => _client.authToken;

  Future<List<ReportRecord>> getReports({String? status}) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    final response = await _client.postJsonValue(
      'api/reports/getAuthorityReports',
      body,
    );
    if (response is Map && response['success'] == false) {
      throw AuthorityServiceException(
        response['message']?.toString() ?? 'Unable to load authority reports.',
      );
    }
    if (response is! List) {
      throw const AuthorityServiceException(
        'Unable to load authority reports.',
      );
    }
    return response
        .map(
          (item) =>
              ReportRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<ReportRecord> getReport({required String reportId}) async {
    final response = await _client.postJson(
      'api/reports/getAuthorityReportData',
      {'Rid': reportId},
    );
    if (response['success'] == false) {
      throw AuthorityServiceException(
        response['message']?.toString() ?? 'Unable to load report.',
      );
    }
    return ReportRecord.fromJson(response);
  }

  Future<ReportRecord> updateStatus({
    required String reportId,
    required String status,
    String? resolutionNote,
  }) async {
    final body = <String, dynamic>{'Rid': reportId, 'status': status};
    if (resolutionNote != null) body['resolutionNote'] = resolutionNote;
    final response = await _client.postJson(
      'api/reports/updateReportStatus',
      body,
    );
    if (response['success'] != true || response['report'] is! Map) {
      throw AuthorityServiceException(
        response['message']?.toString() ?? 'Unable to update report status.',
      );
    }
    return ReportRecord.fromJson(
      Map<String, dynamic>.from(response['report'] as Map),
    );
  }
}

class AuthorityServiceException implements Exception {
  const AuthorityServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}
