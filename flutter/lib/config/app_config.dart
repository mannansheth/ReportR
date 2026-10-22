﻿import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get backendBaseUrl => (dotenv.isInitialized ? dotenv.env['BACKEND_BASE_URL'] : null) ??
      const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

  static String get normalizedBackendBaseUrl {
    final value = backendBaseUrl.trim();
    if (value.isEmpty) return '';
    return value.endsWith('/') ? value : '$value/';
  }
}
