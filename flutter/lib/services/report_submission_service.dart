import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/storage/preferences_service.dart';
import '../models/media_asset.dart';
import '../models/report.dart';
import 'pdf_service.dart';
import 'report_storage_service.dart';
import 'report_upload_service.dart';

enum SubmissionStage { checking, saving, pdf, uploading }

class ReportSubmissionResult {
  const ReportSubmissionResult({
    required this.success,
    this.report,
    this.pdfPath,
    this.message,
    this.duplicateReport,
  });
  final bool success;
  final ReportDraft? report;
  final String? pdfPath;
  final String? message;
  final Map<String, dynamic>? duplicateReport;
}

/// One submission preserves evidence before any external work and only removes
/// the pending marker after the server confirms acceptance.
class ReportSubmissionService {
  ReportSubmissionService({
    required this.preferences,
    required this.storage,
    required this.pdf,
    required this.upload,
    this.nearbyMatches,
  });
  final PreferencesService preferences;
  final ReportStorageService storage;
  final PdfService pdf;
  final ReportUploadService upload;
  final Future<List<Map<String, dynamic>>> Function(ReportDraft draft)?
  nearbyMatches;
  bool _busy = false;

  Future<ReportSubmissionResult> submit({
    required ReportDraft draft,
    required MediaAsset image,
    String? audioPath,
    String languageCode = 'en',
    void Function(SubmissionStage)? onStage,
  }) async {
    if (_busy) {
      return const ReportSubmissionResult(
        success: false,
        message: 'A submission is already in progress.',
      );
    }
    _busy = true;
    ReportDraft? stored;
    String? pdfPath;
    var checkingNearby = false;
    try {
      if (nearbyMatches != null) {
        checkingNearby = true;
        onStage?.call(SubmissionStage.checking);
        final matches = await nearbyMatches!(draft);
        if (matches.isNotEmpty) {
          return ReportSubmissionResult(
            success: false,
            duplicateReport: matches.first,
            message: 'This issue has already been reported nearby.',
          );
        }
        checkingNearby = false;
      }
      onStage?.call(SubmissionStage.saving);
      stored = await storage.saveDraft(
        draft: draft,
        image: image,
        audioPath: audioPath,
      );
      final imagePath = stored.imagePath;
      if (imagePath == null) {
        throw const FileSystemException('Report image is missing.');
      }
      pdfPath = ReportPaths.pdf(Directory(imagePath).parent.path);
      onStage?.call(SubmissionStage.pdf);
      await pdf.generate(
        report: stored,
        imagePath: imagePath,
        outputPath: pdfPath,
        languageCode: languageCode,
      );
      onStage?.call(SubmissionStage.uploading);
      final response = await upload.upload(
        report: stored,
        imagePath: imagePath,
        audioPath: stored.audioPath,
        pdfPath: pdfPath,
      );
      if (!response.isSuccess) {
        return ReportSubmissionResult(
          success: false,
          report: stored,
          pdfPath: pdfPath,
          duplicateReport: response.duplicateReport,
          message:
              response.message ??
              'Upload failed. Your draft is saved for retry.',
        );
      }
      await preferences.removePendingReport(stored.reportID);
      return ReportSubmissionResult(
        success: true,
        report: stored,
        pdfPath: pdfPath,
      );
    } catch (error) {
      debugPrint('Report submission failed: $error');
      return ReportSubmissionResult(
        success: false,
        report: stored,
        pdfPath: pdfPath,
        message: checkingNearby
            ? 'Unable to check nearby reports. Please try again.'
            : stored == null
            ? 'Unable to save the report on this device.'
            : 'Unable to complete submission. Your draft is saved for retry.',
      );
    } finally {
      _busy = false;
    }
  }
}
