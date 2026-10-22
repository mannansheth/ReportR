import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../models/report.dart';

class ReportUploadService {
  const ReportUploadService(this._client);
  final ApiClient _client;

  Future<ReportUploadResult> upload({
    required ReportDraft report,
    required String imagePath,
    String? audioPath,
    required String pdfPath,
  }) async {
    try {
      final response = await _client.postMultipart(
        'api/user/submitReport',
        await buildMultipart(
          report: report,
          imagePath: imagePath,
          audioPath: audioPath,
          pdfPath: pdfPath,
        ),
      );
      if (response is Map && response['success'] == true) {
        return const ReportUploadResult.success();
      }
      if (response is Map &&
          response['code'] == 'NEARBY_DUPLICATE' &&
          response['report'] is Map) {
        return ReportUploadResult.duplicate(
          Map<String, dynamic>.from(response['report'] as Map),
        );
      }
      final message = response is Map
          ? (response['message'] ?? response['error'])?.toString()
          : null;
      return ReportUploadResult.failure(
        message ?? 'The report was not accepted.',
      );
    } on ApiClientException catch (error) {
      if (error.code == 'NEARBY_DUPLICATE' && error.data?['report'] is Map) {
        return ReportUploadResult.duplicate(
          Map<String, dynamic>.from(error.data!['report'] as Map),
        );
      }
      return ReportUploadResult.failure(error.message);
    } catch (_) {
      return const ReportUploadResult.failure('Report upload failed.');
    }
  }

  static Future<FormData> buildMultipart({
    required ReportDraft report,
    required String imagePath,
    String? audioPath,
    required String pdfPath,
  }) async {
    if (!await File(imagePath).exists()) {
      throw const FileSystemException('Report image is missing.');
    }
    if (!await File(pdfPath).exists()) {
      throw const FileSystemException('Report PDF is missing.');
    }
    final imageFormat = await _imageFormat(imagePath);
    final form = <String, dynamic>{
      'reportID': report.reportID,
      'userID': report.userID,
      'name': report.name,
      'number': report.number,
      'category': report.category,
      'description': report.description,
      'location': jsonEncode(report.location.toJson()),
      'createdDate': report.createdDate,
      'image': await MultipartFile.fromFile(
        imagePath,
        filename: 'report_image.${imageFormat == 'jpeg' ? 'jpg' : imageFormat}',
        contentType: DioMediaType('image', imageFormat),
      ),
      'pdf': await MultipartFile.fromFile(
        pdfPath,
        filename: 'report.pdf',
        contentType: DioMediaType('application', 'pdf'),
      ),
    };
    if (audioPath != null) {
      if (!await File(audioPath).exists()) {
        throw const FileSystemException('Report audio is missing.');
      }
      form['audio'] = await MultipartFile.fromFile(
        audioPath,
        filename: 'report_audio.m4a',
        contentType: DioMediaType('audio', 'm4a'),
      );
    }
    return FormData.fromMap(form);
  }

  static Future<String> _imageFormat(String path) async {
    final file = await File(path).open();
    try {
      final bytes = await file.read(12);
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47) {
        return 'png';
      }
      if (bytes.length >= 12 &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
        return 'webp';
      }
      return 'jpeg';
    } finally {
      await file.close();
    }
  }
}

class ReportUploadResult {
  const ReportUploadResult.success()
    : isSuccess = true,
      message = null,
      duplicateReport = null;
  const ReportUploadResult.failure(this.message)
    : isSuccess = false,
      duplicateReport = null;
  const ReportUploadResult.duplicate(this.duplicateReport)
    : isSuccess = false,
      message = 'This issue has already been reported nearby.';

  final bool isSuccess;
  final String? message;
  final Map<String, dynamic>? duplicateReport;
}
