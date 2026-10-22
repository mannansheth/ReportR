import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:reportr_flutter/models/prediction.dart';
import 'package:reportr_flutter/models/user_session.dart';
import 'package:reportr_flutter/screens/home/report_form_screen.dart';
// This platform implementation supplies only a filesystem sandbox; the actual
// storage, PDF, multipart serialization, and submission coordinator execute.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:reportr_flutter/models/media_asset.dart';
import 'package:reportr_flutter/models/report.dart';
import 'package:reportr_flutter/models/report_location.dart';
import 'package:reportr_flutter/services/pdf_service.dart';
import 'package:reportr_flutter/services/report_storage_service.dart';
import 'package:reportr_flutter/services/report_submission_service.dart';
import 'package:reportr_flutter/services/report_upload_service.dart';

class DirectoryProvider extends PathProviderPlatform {
  DirectoryProvider(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class UploadEndpoint extends ApiClient {
  bool fail = true;
  Completer<void>? pause;
  int requests = 0;
  @override
  Future<dynamic> postMultipart(
    String path,
    FormData data, {
    Duration? receiveTimeout,
  }) async {
    requests++;
    expect(path, 'api/user/submitReport');
    expect(data.fields.any((field) => field.key == 'reportID'), isTrue);
    expect(data.files.map((entry) => entry.key), containsAll(['image', 'pdf']));
    await pause?.future;
    return {'success': !fail, 'message': 'Test upload rejected'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  late PreferencesService preferences;
  late MediaAsset image;
  late ReportDraft draft;
  late UploadEndpoint endpoint;
  late ReportSubmissionService service;
  late PathProviderPlatform oldProvider;
  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('reportr-submit-');
    oldProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = DirectoryProvider(sandbox.path);
    SharedPreferences.setMockInitialValues({});
    preferences = await PreferencesService.create();
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC';
    final file = File('${sandbox.path}/source.png');
    await file.writeAsBytes(base64Decode(png));
    image = MediaAsset(path: file.path, base64: png, mimeType: 'image/png');
    draft = ReportDraft(
      reportID: 'Rid_test',
      userID: '1',
      name: 'Citizen',
      number: '9999999999',
      category: 'Pothole',
      description: 'Damaged road',
      location: const ReportLocation(
        latitude: 19,
        longitude: 72,
        readableLocation: 'Test road',
      ),
      createdDate: DateTime.utc(2026, 10, 15).toIso8601String(),
    );
    endpoint = UploadEndpoint();
    service = ReportSubmissionService(
      preferences: preferences,
      storage: ReportStorageService(preferences),
      pdf: PdfService(),
      upload: ReportUploadService(endpoint),
    );
  });
  tearDown(() async {
    PathProviderPlatform.instance = oldProvider;
    await sandbox.delete(recursive: true);
  });
  test(
    'nearby duplicate stops before saving evidence, generating PDF or uploading',
    () async {
      final stages = <SubmissionStage>[];
      final guarded = ReportSubmissionService(
        preferences: preferences,
        storage: ReportStorageService(preferences),
        pdf: PdfService(),
        upload: ReportUploadService(endpoint),
        nearbyMatches: (candidate) async {
          expect(candidate.category, 'Pothole');
          expect(candidate.location.latitude, 19);
          return [
            {'Rid': 'Rid_existing', 'confirmationCount': 4},
          ];
        },
      );
      final result = await guarded.submit(
        draft: draft,
        image: image,
        onStage: stages.add,
      );
      expect(result.success, isFalse);
      expect(result.duplicateReport?['Rid'], 'Rid_existing');
      expect(stages, [SubmissionStage.checking]);
      expect(preferences.pendingReports, isEmpty);
      expect(endpoint.requests, 0);
      expect(await Directory('${sandbox.path}/reports').exists(), isFalse);
    },
  );
  test(
    'a failed nearby lookup cannot silently create a new duplicate',
    () async {
      final guarded = ReportSubmissionService(
        preferences: preferences,
        storage: ReportStorageService(preferences),
        pdf: PdfService(),
        upload: ReportUploadService(endpoint),
        nearbyMatches: (_) async =>
            throw const ApiClientException('Service unavailable'),
      );
      final result = await guarded.submit(draft: draft, image: image);
      expect(result.success, isFalse);
      expect(
        result.message,
        'Unable to check nearby reports. Please try again.',
      );
      expect(endpoint.requests, 0);
    },
  );
  test(
    'one action persists evidence, generates a genuine PDF, uploads and retains failed drafts for retry',
    () async {
      final stages = <SubmissionStage>[];
      final failed = await service.submit(
        draft: draft,
        image: image,
        onStage: stages.add,
      );
      expect(failed.success, isFalse);
      expect(stages, [
        SubmissionStage.saving,
        SubmissionStage.pdf,
        SubmissionStage.uploading,
      ]);
      expect(preferences.pendingReports, [draft.reportID]);
      final reloaded = await ReportStorageService(
        preferences,
      ).loadDraft(draft.reportID);
      expect(reloaded?.imagePath, isNotNull);
      expect(await File(reloaded!.imagePath!).exists(), isTrue);
      final bytes = await File(failed.pdfPath!).readAsBytes();
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      endpoint.fail = false;
      final accepted = await service.submit(draft: reloaded, image: image);
      expect(accepted.success, isTrue);
      expect(endpoint.requests, 2);
      expect(preferences.pendingReports, isEmpty);
      expect(await File(accepted.pdfPath!).exists(), isTrue);
    },
  );
  test(
    'a second concurrent submission cannot duplicate storage or upload',
    () async {
      endpoint.pause = Completer<void>();
      endpoint.fail = false;
      final started = service.submit(draft: draft, image: image);
      final duplicate = await service.submit(draft: draft, image: image);
      expect(duplicate.success, isFalse);
      expect(duplicate.message, contains('already in progress'));
      endpoint.pause!.complete();
      expect((await started).success, isTrue);
      expect(endpoint.requests, 1);
    },
  );
  test(
    'legacy drafts recover image and audio paths from their existing directory',
    () async {
      await ReportStorageService(
        preferences,
      ).saveDraft(draft: draft, image: image);
      final directory = ReportPaths.directory(sandbox.path, draft.reportID);
      final json =
          jsonDecode(await File(ReportPaths.data(directory)).readAsString())
              as Map<String, dynamic>;
      json.remove('imagePath');
      json.remove('audioPath');
      await File(ReportPaths.data(directory)).writeAsString(jsonEncode(json));
      await File(ReportPaths.audio(directory)).writeAsBytes([1, 2, 3]);
      final recovered = await ReportStorageService(
        preferences,
      ).loadDraft(draft.reportID);
      expect(recovered?.imagePath, ReportPaths.image(directory));
      expect(recovered?.audioPath, ReportPaths.audio(directory));
    },
  );

  testWidgets(
    'one Submit tap generates and sends the report, then shows PDF download/share actions',
    (tester) async {
      endpoint.fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ReportFormScreen(
            session: const UserSession(
              id: '1',
              name: 'Citizen',
              number: '9999999999',
            ),
            preferences: preferences,
            image: image,
            location: draft.location,
            predictions: const [
              Prediction(
                issue: 'Pothole',
                probability: .9,
                description: 'Damaged road',
                boundingBox: [0, 0, 400, 400],
              ),
            ],
            initiallyExpanded: false,
            submissionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prepare report and PDF'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('submit-report')));
        for (
          var attempt = 0;
          attempt < 100 && endpoint.requests == 0;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(
        endpoint.requests,
        1,
        reason:
            'pending=${preferences.pendingReports}, files=${sandbox.listSync(recursive: true).map((f) => f.path).toList()}',
      );
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(preferences.pendingReports, isEmpty);
      for (
        var attempt = 0;
        attempt < 10 && find.text('Download PDF').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Share PDF'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Done'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
  );
}
