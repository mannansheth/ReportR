import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:reportr_flutter/l10n/ui_strings.dart';
import 'package:reportr_flutter/services/report_pdf_service.dart';
import 'package:reportr_flutter/widgets/report_pdf_actions.dart';

void main() {
  final bytes = Uint8List.fromList('%PDF-1.4\n%%EOF'.codeUnits);
  test(
    'local report PDF works offline and invalid data is never shared as PDF',
    () async {
      final root = await Directory.systemTemp.createTemp('reportr-pdf-');
      addTearDown(() => root.delete(recursive: true));
      final local = File('${root.path}/reports/Rid_test/report.pdf');
      await local.parent.create(recursive: true);
      await local.writeAsBytes(bytes);
      final service = ReportPdfService(documentsDirectory: () async => root);
      expect(await service.load('Rid_test'), bytes);
      expect(ReportPdfService.isPdf('<html>Error</html>'.codeUnits), isFalse);
      expect(
        () => ReportPdfService.fileName('../escape'),
        throwsFormatException,
      );
    },
  );
  test(
    'denied CDN PDF recovers through owner endpoint and is cached',
    () async {
      dotenv.loadFromString(
        envString: 'BACKEND_BASE_URL=http://127.0.0.1:5002/',
      );
      final root = await Directory.systemTemp.createTemp('reportr-pdf-');
      addTearDown(() => root.delete(recursive: true));
      final adapter = _Adapter(bytes);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ReportPdfService(
        dio: dio,
        authToken: 'test-token',
        documentsDirectory: () async => root,
      );
      expect(
        await service.load(
          'Rid_test',
          remoteUrl: 'https://cdn.example/report.pdf',
        ),
        bytes,
      );
      final backend = adapter.requests.singleWhere(
        (r) => r.uri.host == '127.0.0.1',
      );
      expect(backend.path, endsWith('/api/reports/Rid_test/pdf'));
      expect(backend.headers['Authorization'], 'Bearer test-token');
      for (final request in adapter.requests.where(
        (r) => r.uri.host == 'cdn.example',
      )) {
        expect(request.headers.containsKey('Authorization'), isFalse);
      }
      final count = adapter.requests.length;
      expect(await service.load('Rid_test'), bytes);
      expect(adapter.requests.length, count);
    },
  );
  for (final language in ['en', 'hi', 'mr']) {
    testWidgets(
      'PDF modal $language offers save/share and cancellation has no success message',
      (tester) async {
        final service = _FakePdfService(bytes);
        final strings = UiStrings(language);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showReportPdfActions(
                    context,
                    reportId: 'Rid_test',
                    submitted: true,
                    service: service,
                  ),
                  child: const Text('Launch'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Launch'));
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Report submitted')), findsOneWidget);
        expect(find.text(strings.text('View PDF')), findsOneWidget);
        await tester.tap(find.text(strings.text('Download PDF')));
        await tester.pumpAndSettle();
        expect(service.saved, 1);
        expect(
          find.text(strings.text('PDF saved to the selected location.')),
          findsNothing,
        );
        await tester.tap(find.text(strings.text('Share PDF')));
        await tester.pumpAndSettle();
        expect(service.shared, 1);
        await tester.tap(find.text(strings.text('Done')));
        await tester.pumpAndSettle();
        expect(find.text(strings.text('Report submitted')), findsNothing);
      },
    );
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.bytes);
  final Uint8List bytes;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return options.uri.host == 'cdn.example'
        ? ResponseBody.fromString('Denied', 401)
        : ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

class _FakePdfService extends ReportPdfService {
  _FakePdfService(this.bytes);
  final Uint8List bytes;
  int saved = 0, shared = 0;
  @override
  Future<Uint8List> load(
    String reportId, {
    String? localPath,
    String? remoteUrl,
  }) async => bytes;
  @override
  Future<bool> save(Uint8List bytes, String reportId) async {
    saved++;
    return false;
  }

  @override
  Future<bool> share(Uint8List bytes, String reportId, {Rect? origin}) async {
    shared++;
    return false;
  }
}
