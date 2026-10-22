import '../config/constants.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/user_session.dart';

class SessionService {
  const SessionService(this._storage);

  static const authTokenKey = 'authToken';
  final SecureStorageService _storage;

  Future<UserSession?> readSession() async {
    final raw = await _storage.read(AppConstants.userDetailsKey);
    if (raw == null || raw.isEmpty) return null;
    return UserSession.fromJsonString(raw);
  }

  Future<String?> readAuthToken() => _storage.read(authTokenKey);
  Future<bool> saveAuthToken(String token) => _storage.write(authTokenKey, token);
  Future<bool> clearAuthToken() => _storage.delete(authTokenKey);

  Future<bool> saveSession(UserSession session) => _storage.write(AppConstants.userDetailsKey, session.toJsonString());
  Future<bool> clearSession() => _storage.delete(AppConstants.userDetailsKey);
}