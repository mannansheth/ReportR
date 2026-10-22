import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../config/app_config.dart';
import 'report_storage_service.dart';

class ReportPdfService {
  ReportPdfService({
    Dio? dio,
    this.authToken,
    Future<Directory> Function()? documentsDirectory,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;
  final Dio _dio;
  final String? authToken;
  final Future<Directory> Function() _documentsDirectory;

  static String fileName(String id) => '${_safeId(id)}.pdf';
  static String _safeId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('Invalid report ID');
    }
    return id;
  }

  static bool isPdf(List<int> bytes) =>
      bytes.length >= 5 &&
      ascii.decode(bytes.take(5).toList(), allowInvalid: true) == '%PDF-';

  Future<Uint8List> load(
    String reportId, {
    String? localPath,
    String? remoteUrl,
  }) async {
    final id = _safeId(reportId);
    final documents = await _documentsDirectory();
    final cached = File(
      ReportPaths.pdf(ReportPaths.directory(documents.path, id)),
    );
    for (final path in {?localPath, cached.path}) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (isPdf(bytes)) return bytes;
      }
    }
    final base = AppConfig.normalizedBackendBaseUrl;
    if (base.isNotEmpty && authToken != null && authToken!.isNotEmpty) {
      try {
        final response = await _dio.get<List<int>>(
          '${base}api/reports/$id/pdf',
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Authorization': 'Bearer $authToken'},
          ),
        );
        final bytes = response.data;
        if (bytes != null && isPdf(bytes)) return _cache(cached, bytes);
      } catch (_) {
        // Surface one actionable localized error rather than a CDN HTML page.
      }
    }
    final remote = Uri.tryParse(remoteUrl ?? '');
    if (remote != null &&
        remote.hasAuthority &&
        ['http', 'https'].contains(remote.scheme)) {
      try {
        final response = await _dio.get<List<int>>(
          remote.toString(),
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        if (bytes != null && isPdf(bytes)) return _cache(cached, bytes);
      } catch (_) {
        // Private backend copy is the recovery path for denied CDN delivery.
      }
    }
    throw const ReportPdfException(
      'Unable to load the report PDF. Please try again.',
    );
  }

  Future<Uint8List> _cache(File file, List<int> bytes) async {
    final result = Uint8List.fromList(bytes);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(result, flush: true);
    return result;
  }

  Future<bool> save(Uint8List bytes, String reportId) async {
    if (!isPdf(bytes)) {
      throw const ReportPdfException(
        'Unable to save this PDF. Please try again.',
      );
    }
    final output = await FilePicker.saveFile(
      fileName: fileName(reportId),
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    return output != null;
  }

  Future<bool> share(Uint8List bytes, String reportId, {Rect? origin}) {
    if (!isPdf(bytes)) {
      throw const ReportPdfException(
        'Unable to share this PDF. Please try again.',
      );
    }
    return Printing.sharePdf(
      bytes: bytes,
      filename: fileName(reportId),
      bounds: origin,
    );
  }
}

class ReportPdfException implements Exception {
  const ReportPdfException(this.message);
  final String message;
  @override
  String toString() => message;
}
