// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reportr_flutter/models/report.dart';
import 'package:reportr_flutter/models/report_location.dart';
import 'package:reportr_flutter/services/audio_recording_service.dart';
import 'package:reportr_flutter/services/report_storage_service.dart';
import 'package:reportr_flutter/services/report_upload_service.dart';

void main() {
  const location = ReportLocation(
    latitude: 19.04,
    longitude: 72.87,
    readableLocation: 'Name, Street, City, Region, 400001, India',
  );

  test('report IDs retain enough entropy within the backend column width', () {
    final id = ReportIdGenerator.generate(
      now: DateTime(2026, 9, 6),
      uuid: '1234-5678-90ab-cdef',
    );
    expect(id, 'Rid_20261234567890ab');
    expect(id.length, 20);
    expect(
      ReportIdGenerator.generate(
        now: DateTime(2026),
        uuid: '1234-9999-90ab-cdef',
      ),
      isNot(id),
    );
  });

  test('report drafts retain local evidence paths for upload retries', () {
    const draft = ReportDraft(
      reportID: 'Rid_20261234',
      userID: '7',
      name: 'Example',
      number: '9876543210',
      category: 'Pothole',
      description: 'Road damage',
      location: location,
      createdDate: '2026-09-06T10:00:00.000Z',
      imagePath: '/local/image.jpeg',
      audioPath: '/local/audio.m4a',
    );

    final json = draft.toJson();
    expect(json['reportID'], 'Rid_20261234');
    expect(json['userID'], '7');
    expect(json['location'], {
      'lat': 19.04,
      'lng': 72.87,
      'loc': 'Name, Street, City, Region, 400001, India',
    });
    expect(json['imagePath'], '/local/image.jpeg');
    expect(json['audioPath'], '/local/audio.m4a');
    final restored = ReportDraft.fromJson(json);
    expect(restored.category, 'Pothole');
    expect(restored.imagePath, '/local/image.jpeg');
    expect(restored.audioPath, '/local/audio.m4a');
  });

  test('report paths preserve local filenames', () {
    final directory = ReportPaths.directory('root', 'Rid_20261234');
    expect(ReportPaths.image(directory), endsWith('image.jpeg'));
    expect(ReportPaths.audio(directory), endsWith('audio.m4a'));
    expect(ReportPaths.data(directory), endsWith('data.json'));
  });

  test('audio constants preserve later multipart contract', () {
    expect(AudioRecordingService.localFileName, 'audio.m4a');
    expect(AudioRecordingService.uploadFileName, 'recording.m4a');
    expect(AudioRecordingService.mimeType, 'audio/m4a');
  });
  test(
    'pending report IDs persist through the existing preferences key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await PreferencesService.create();
      await preferences.addPendingReport('Rid_20261234');
      expect(preferences.pendingReports, ['Rid_20261234']);
    },
  );

  test(
    'multipart upload preserves backend field names and file metadata',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'reportr-upload-test',
      );
      final image = File(directory.path + Platform.pathSeparator + 'image.jpeg')
        ..writeAsBytesSync([1, 2, 3]);
      final audio = File(directory.path + Platform.pathSeparator + 'audio.m4a')
        ..writeAsBytesSync([4, 5]);
      final pdf = File(directory.path + Platform.pathSeparator + 'report.pdf')
        ..writeAsBytesSync([6, 7]);
      const draft = ReportDraft(
        reportID: 'Rid_20261234',
        userID: '7',
        name: 'Example',
        number: '9876543210',
        category: 'Pothole',
        description: 'Road damage',
        location: location,
        createdDate: '2026-09-06T10:00:00.000Z',
      );
      final form = await ReportUploadService.buildMultipart(
        report: draft,
        imagePath: image.path,
        audioPath: audio.path,
        pdfPath: pdf.path,
      );
      expect(
        form.fields.map((entry) => entry.key),
        containsAll(['reportID', 'userID', 'location', 'createdDate']),
      );
      final files = <String, dynamic>{
        for (final entry in form.files) entry.key: entry.value,
      };
      expect(files.keys, containsAll(['image', 'audio', 'pdf']));
      expect(files['image'].filename, 'report_image.jpg');
      expect(files['image'].contentType.toString(), 'image/jpeg');
      expect(files['audio'].filename, 'report_audio.m4a');
      expect(files['audio'].contentType.toString(), 'audio/m4a');
      expect(files['pdf'].filename, 'report.pdf');
      await directory.delete(recursive: true);
    },
  );
}
