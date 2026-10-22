import '../core/network/api_client.dart';
import '../models/user_session.dart';

class ProfileService {
  const ProfileService(this.client);
  final ApiClient client;
  Future<UserSession> getProfile() async {
    final value = await client.getJson('api/user/profile');
    if (value is! Map) {
      throw const ApiClientException('Unable to load your profile.');
    }
    return _parse(Map<String, dynamic>.from(value));
  }

  Future<UserSession> updateName(String name) async {
    final response = await client.postJson('api/user/updateProfile', {
      'name': name.trim(),
    });
    return _parse(response);
  }

  UserSession _parse(Map<String, dynamic> response) {
    if (response['success'] != true || response['user'] is! Map) {
      throw ApiClientException(
        response['message']?.toString() ?? 'Unable to update your profile.',
      );
    }
    final user = Map<String, dynamic>.from(response['user'] as Map);
    return UserSession(
      id: user['id'].toString(),
      name: user['name'].toString(),
      number: user['phone'].toString(),
      role: user['role']?.toString() ?? 'Citizen',
    );
  }
}
