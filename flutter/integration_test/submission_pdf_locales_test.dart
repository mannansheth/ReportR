import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/core/storage/preferences_service.dart';
import 'package:reportr_flutter/l10n/app_localizations.dart';
import 'package:reportr_flutter/l10n/ui_strings.dart';
import 'package:reportr_flutter/models/media_asset.dart';
import 'package:reportr_flutter/models/prediction.dart';
import 'package:reportr_flutter/models/report.dart';
import 'package:reportr_flutter/models/report_location.dart';
import 'package:reportr_flutter/models/report_record.dart';
import 'package:reportr_flutter/models/user_session.dart';
import 'package:reportr_flutter/screens/home/report_form_screen.dart';
import 'package:reportr_flutter/screens/reports/reports_screen.dart';
import 'package:reportr_flutter/services/pdf_service.dart';
import 'package:reportr_flutter/services/report_pdf_service.dart';
import 'package:reportr_flutter/services/report_service.dart';
import 'package:reportr_flutter/services/report_storage_service.dart';
import 'package:reportr_flutter/services/report_submission_service.dart';
import 'package:reportr_flutter/services/report_upload_service.dart';
import 'package:reportr_flutter/widgets/report_pdf_actions.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final language in ['en', 'hi', 'mr']) {
    testWidgets(
      'phone $language: one submit, PDF modal, real PDF preview, reports PDF',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await PreferencesService.create();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 900, 600),
          Paint()..color = const Color(0xFF778E9B),
        );
        canvas.drawOval(
          const Rect.fromLTWH(180, 240, 400, 210),
          Paint()..color = const Color(0xFF17303F),
        );
        final image = await recorder.endRecording().toImage(900, 600);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File(
          '${(await getTemporaryDirectory()).path}/qa-submit-$language.png',
        );
        await file.writeAsBytes(png!.buffer.asUint8List());
        final upload = _AcceptUpload();
        final submission = ReportSubmissionService(
          preferences: prefs,
          storage: ReportStorageService(prefs),
          pdf: PdfService(),
          upload: upload,
        );
        final strings = UiStrings(language);
        const session = UserSession(
          id: 'qa-device',
          name: 'आदित्य शर्मा',
          number: '9999999900',
        );
        final location = ReportLocation(
          latitude: 19.076,
          longitude: 72.8777,
          readableLocation: language == 'en'
              ? 'Municipal market, Mumbai, Maharashtra'
              : 'महानगरपालिका बाजार, मुंबई, महाराष्ट्र',
        );
        Widget app(Widget child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF12364B),
            ),
          ),
          home: child,
        );
        await tester.pumpWidget(
          app(
            ReportFormScreen(
              session: session,
              preferences: prefs,
              image: MediaAsset(
                path: file.path,
                base64: base64Encode(await file.readAsBytes()),
                mimeType: 'image/png',
              ),
              location: location,
              initiallyExpanded: false,
              submissionService: submission,
              predictions: [
                const Prediction(
                  issue: 'Pothole',
                  probability: .95,
                  description: 'सड़क पर बड़ा गड्ढा है।',
                  boundingBox: [400, 200, 750, 644],
                ),
                const Prediction(
                  issue: 'Garbage overflow',
                  probability: .8,
                  description: 'कचरा साचला आहे.',
                  boundingBox: [100, 700, 300, 950],
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Prepare report and PDF'), findsNothing);
        expect(find.text(strings.text('Submit report')), findsOneWidget);
        if (language == 'en') await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('submit-form-$language');
        await tester.tap(find.text(strings.text('Submit report')));
        for (
          var i = 0;
          i < 100 &&
              find.text(strings.text('Report submitted')).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pumpAndSettle();
        expect(upload.calls, 1);
        expect(upload.report!.category, 'Pothole, Garbage overflow');
        expect(prefs.pendingReports, isEmpty);
        expect(find.text(strings.text('Report submitted')), findsOneWidget);
        expect(find.text(strings.text('Download PDF')), findsOneWidget);
        expect(find.text(strings.text('Share PDF')), findsOneWidget);
        await binding.takeScreenshot('submit-pdf-modal-$language');
        await tester.tap(find.text(strings.text('View PDF')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(ReportPdfPreviewScreen), findsOneWidget);
        await binding.takeScreenshot('report-pdf-preview-$language');
        await tester.pageBack();
        await tester.pumpAndSettle();
        final record = ReportRecord(
          id: upload.report!.reportID,
          userId: session.id,
          issue: upload.report!.category,
          description: upload.report!.description,
          location: location.toJson(),
          createdAt: upload.report!.createdDate,
          status: 'Verification pending',
        );
        await tester.pumpWidget(
          app(
            Scaffold(
              body: ReportsScreen(
                initialMine: true,
                session: session,
                reportService: _FixtureReports(record),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Report PDF')), findsOneWidget);
        await tester.tap(find.text(strings.text('Report PDF')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(strings.text('Report PDF')),
          ),
          findsOneWidget,
        );
        await binding.takeScreenshot('reports-pdf-actions-$language');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        final root = await getApplicationDocumentsDirectory();
        final directory = Directory(
          ReportPaths.directory(root.path, record.id),
        );
        if (await directory.exists()) await directory.delete(recursive: true);
        await file.delete();
      },
    );
  }
}

class _AcceptUpload extends ReportUploadService {
  _AcceptUpload() : super(ApiClient());
  int calls = 0;
  ReportDraft? report;
  @override
  Future<ReportUploadResult> upload({
    required ReportDraft report,
    required String imagePath,
    String? audioPath,
    required String pdfPath,
  }) async {
    calls++;
    this.report = report;
    expect(ReportPdfService.isPdf(await File(pdfPath).readAsBytes()), isTrue);
    final multipart = await ReportUploadService.buildMultipart(
      report: report,
      imagePath: imagePath,
      pdfPath: pdfPath,
      audioPath: audioPath,
    );
    expect(multipart.files.any((entry) => entry.key == 'pdf'), isTrue);
    return const ReportUploadResult.success();
  }
}

class _FixtureReports extends ReportService {
  _FixtureReports(this.report) : super(ApiClient());
  final ReportRecord report;
  @override
  Future<List<ReportRecord>> getUserReports(String userId) async => [report];
  @override
  Future<ReportRecord> getReportDetails({
    required String reportId,
    required String userId,
  }) async => report;
  @override
  Future<List<ReportStatusEvent>> getStatusHistory({
    required String reportId,
  }) async => [];
}
