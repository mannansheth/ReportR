import '../core/network/api_client.dart';

class ReportNotificationService {
  const ReportNotificationService(this._client);
  final ApiClient _client;

  Future<bool> sendReportRaised({
    required String reportId,
    required String name,
    required String userId,
  }) async {
    try {
      final response = await _client.postJsonValue(
        'api/user/sendNotification',
        {'Rid': reportId, 'name': name, 'userId': userId},
      );
      return response is Map && response['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
