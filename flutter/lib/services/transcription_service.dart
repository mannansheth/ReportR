import 'dart:io';

import 'package:dio/dio.dart';

import '../core/network/api_client.dart';

class TranscriptionService {
  const TranscriptionService(this._client);
  final ApiClient _client;

  Future<TranscriptionResult> transcribe(String audioPath) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      return const TranscriptionResult.failure('Audio file is missing.');
    }
    try {
      final response = await _client.postMultipart(
        'api/transcribeDescription',
        FormData.fromMap({
          'audio': await MultipartFile.fromFile(
            audioPath,
            filename: 'recording.m4a',
            contentType: DioMediaType('audio', 'm4a'),
          ),
        }),
        receiveTimeout: const Duration(minutes: 2),
      );
      if (response is Map && response['success'] == true) {
        final result = response['result'];
        final text = result is Map ? result['text']?.toString() : null;
        if (text != null && text.trim().isNotEmpty) {
          return TranscriptionResult.success(text.trim());
        }
      }
      return const TranscriptionResult.failure('Transcription was not available.');
    } on ApiClientException catch (error) {
      return TranscriptionResult.failure(error.message);
    } catch (_) {
      return const TranscriptionResult.failure('Transcription failed.');
    }
  }
}

class TranscriptionResult {
  const TranscriptionResult.success(this.text)
      : isSuccess = true,
        message = null;
  const TranscriptionResult.failure(this.message)
      : isSuccess = false,
        text = null;

  final bool isSuccess;
  final String? text;
  final String? message;
}
