﻿import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';

import '../models/media_asset.dart';

class MediaService {
  Future<MediaAsset?> pickImage() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;
    return _readFile(result.files.single.path!, null);
  }

  Future<MediaAsset> readCameraFile(XFile file) => _readFile(file.path, 'image/jpeg');

  Future<MediaAsset> _readFile(String path, String? suppliedMimeType) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) throw const FormatException('Selected image is empty.');
    return MediaAsset(
      path: path,
      base64: base64Encode(bytes),
      mimeType: _mimeType(path, suppliedMimeType),
    );
  }

  String _mimeType(String path, String? supplied) {
    if (supplied != null && supplied.startsWith('image/')) return supplied;
    final extension = path.split('.').last.toLowerCase();
    return const {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
          'gif': 'image/gif',
          'heic': 'image/heic',
          'heif': 'image/heif',
        }[extension] ??
        'image/jpeg';
  }
}
