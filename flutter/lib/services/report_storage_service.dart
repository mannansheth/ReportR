// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/storage/preferences_service.dart';
import '../models/media_asset.dart';
import '../models/report.dart';

class ReportPaths {
  const ReportPaths._();

  static String directory(String root, String reportId) =>
      root +
      Platform.pathSeparator +
      'reports' +
      Platform.pathSeparator +
      reportId;
  static String image(String directory) =>
      directory + Platform.pathSeparator + 'image.jpeg';
  static String audio(String directory) =>
      directory + Platform.pathSeparator + 'audio.m4a';
  static String data(String directory) =>
      directory + Platform.pathSeparator + 'data.json';
  static String pdf(String directory) =>
      directory + Platform.pathSeparator + 'report.pdf';
}

class ReportStorageService {
  const ReportStorageService(this._preferences);
  final PreferencesService _preferences;

  Future<Directory> _reportsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(root.path + Platform.pathSeparator + 'reports');
    await directory.create(recursive: true);
    return directory;
  }

  Future<ReportDraft> saveDraft({
    required ReportDraft draft,
    required MediaAsset image,
    String? audioPath,
  }) async {
    final reports = await _reportsDirectory();
    final directory = Directory(
      ReportPaths.directory(reports.parent.path, draft.reportID),
    );
    await directory.create(recursive: true);

    final imagePath = ReportPaths.image(directory.path);
    await _copyIfNeeded(File(image.path), File(imagePath));

    String? storedAudioPath;
    if (audioPath != null) {
      storedAudioPath = ReportPaths.audio(directory.path);
      await _copyIfNeeded(File(audioPath), File(storedAudioPath));
    }

    final stored = ReportDraft(
      reportID: draft.reportID,
      userID: draft.userID,
      name: draft.name,
      number: draft.number,
      category: draft.category,
      description: draft.description,
      location: draft.location,
      createdDate: draft.createdDate,
      imagePath: imagePath,
      audioPath: storedAudioPath,
    );
    await File(
      ReportPaths.data(directory.path),
    ).writeAsString(jsonEncode(stored.toJson()));
    await _preferences.addPendingReport(stored.reportID);
    return stored;
  }

  Future<ReportDraft?> loadDraft(String reportId) async {
    try {
      final reports = await _reportsDirectory();
      final directory = Directory(
        ReportPaths.directory(reports.parent.path, reportId),
      );
      final data = await File(ReportPaths.data(directory.path)).readAsString();
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['imagePath'] == null) {
        final image = File(ReportPaths.image(directory.path));
        if (await image.exists()) json['imagePath'] = image.path;
      }
      if (json['audioPath'] == null) {
        final audio = File(ReportPaths.audio(directory.path));
        if (await audio.exists()) json['audioPath'] = audio.path;
      }
      return ReportDraft.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _copyIfNeeded(File source, File destination) async {
    if (source.path == destination.path) return;
    await source.copy(destination.path);
  }
}
