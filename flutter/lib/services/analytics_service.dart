import '../core/network/api_client.dart';
import '../models/community_analytics.dart';

class AnalyticsService {
  const AnalyticsService(this.client);
  final ApiClient client;
  Future<CommunityAnalytics> load({required String scope}) async {
    final response = await client.getJson('api/reports/analytics?scope=$scope');
    if (response is! Map ||
        response['success'] == false ||
        response['total'] == null) {
      throw ApiClientException(
        response is Map
            ? response['message']?.toString() ??
                  'Unable to load analytics. Please try again.'
            : 'Unable to load analytics. Please try again.',
      );
    }
    return CommunityAnalytics.fromJson(Map<String, dynamic>.from(response));
  }
}
