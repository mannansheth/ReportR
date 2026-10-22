﻿import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';

class PreferencesService {
  PreferencesService._(this._preferences);

  final SharedPreferences _preferences;

  static Future<PreferencesService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return PreferencesService._(preferences);
  }

  String? get token => _preferences.getString(AppConstants.tokenKey);
  Future<bool> setToken(String token) => _preferences.setString(AppConstants.tokenKey, token);
  Future<bool> clearToken() => _preferences.remove(AppConstants.tokenKey);

  String? get userLanguage => _preferences.getString(AppConstants.userLanguageKey);
  Future<bool> setUserLanguage(String languageCode) => _preferences.setString(AppConstants.userLanguageKey, languageCode);
  Future<bool> clearUserLanguage() => _preferences.remove(AppConstants.userLanguageKey);

  List<String> get pendingReports {
    final raw = _preferences.getString(AppConstants.pendingReportsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<String>().toList(growable: false);
    } catch (_) {
      return const [];
    }
    return const [];
  }

  Future<bool> setPendingReports(List<String> reportIds) => _preferences.setString(AppConstants.pendingReportsKey, jsonEncode(reportIds));
  Future<bool> addPendingReport(String reportId) => setPendingReports(pendingReports.contains(reportId) ? pendingReports : [...pendingReports, reportId]);
  Future<bool> removePendingReport(String reportId) => setPendingReports(pendingReports.where((id) => id != reportId).toList());
  Future<bool> clearPendingReports() => _preferences.remove(AppConstants.pendingReportsKey);
}
