// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecordingService {
  static const localFileName = 'audio.m4a';
  static const uploadFileName = 'recording.m4a';
  static const mimeType = 'audio/m4a';
  AudioRecorder? _recorder;
  AudioRecorder get _activeRecorder => _recorder ??= AudioRecorder();

  Future<String?> start() async {
    if (!await _activeRecorder.hasPermission()) return null;
    final temporary = await getTemporaryDirectory();
    final path = temporary.path + Platform.pathSeparator + localFileName;
    await _activeRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    return path;
  }

  Future<String?> stop() async => _recorder?.stop();

  Future<void> discard(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> dispose() async {
    final recorder = _recorder;
    _recorder = null;
    if (recorder != null) await recorder.dispose();
  }
}
