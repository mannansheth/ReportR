import 'package:dio/dio.dart';

import '../../config/app_config.dart';

abstract class AuthClient {
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body);
}

class ApiClient implements AuthClient {
  ApiClient({Dio? dio, this.authToken}) : _dio = dio ?? Dio();

  final Dio _dio;
  final String? authToken;

  Dio get _configuredDio {
    final baseUrl = AppConfig.normalizedBackendBaseUrl;
    if (baseUrl.isEmpty) {
      throw const ApiClientException('Backend base URL is not configured.');
    }
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      contentType: 'application/json',
      headers: authToken == null || authToken!.isEmpty
          ? <String, dynamic>{}
          : <String, dynamic>{'Authorization': 'Bearer $authToken'},
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    );
    return _dio;
  }

  Future<dynamic> getJson(String path) async {
    try {
      final response = await _configuredDio.get<dynamic>(path);
      return response.data;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final value = await postJsonValue(path, body);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ApiClientException('Backend returned an invalid response.');
  }

  Future<dynamic> postMultipart(
    String path,
    FormData data, {
    Duration? receiveTimeout,
  }) async {
    try {
      final dio = _configuredDio;
      if (receiveTimeout != null) {
        dio.options = dio.options.copyWith(receiveTimeout: receiveTimeout);
      }
      final response = await dio.post<dynamic>(path, data: data);
      return response.data;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  Future<dynamic> postJsonValue(String path, Map<String, dynamic> body) async {
    try {
      final response = await _configuredDio.post<dynamic>(path, data: body);
      return response.data;
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  ApiClientException _failure(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      return ApiClientException(
        message is String && message.isNotEmpty
            ? message
            : 'The request could not be completed. Please try again.',
        statusCode: error.response?.statusCode,
        code: data['code']?.toString(),
        data: Map<String, dynamic>.from(data),
      );
    }
    if (error.response?.statusCode == 401) {
      return const ApiClientException(
        'Your session has expired. Sign out and sign in again.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiClientException(
        'The server took too long to respond. Please try again.',
      );
    }
    if (error.response == null) {
      return const ApiClientException(
        'Cannot reach the server. Check your connection and try again.',
      );
    }
    return ApiClientException(
      'Request failed (${error.response?.statusCode}). Please try again.',
    );
  }
}

class ApiClientException implements Exception {
  const ApiClientException(
    this.message, {
    this.statusCode,
    this.code,
    this.data,
  });
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? data;

  @override
  String toString() => message;
}
