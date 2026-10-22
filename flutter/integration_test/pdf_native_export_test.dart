import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reportr_flutter/services/report_pdf_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('phone: native PDF download and share sheet', (tester) async {
    final file = File('${(await getTemporaryDirectory()).path}/qa-source.pdf');
    final bytes = await file.readAsBytes();
    expect(ReportPdfService.isPdf(bytes), isTrue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('PDF export validation'))),
      ),
    );
    await tester.pumpAndSettle();
    final service = ReportPdfService();
    debugPrint('QA_SAVE_DIALOG_OPENING');
    expect(await service.save(bytes, 'Rid_QA_export'), isTrue);
    debugPrint('QA_SAVE_COMPLETED_SHARE_OPENING');
    expect(await service.share(bytes, 'Rid_QA_export'), isTrue);
    await Future<void>.delayed(const Duration(seconds: 15));
    debugPrint('QA_NATIVE_EXPORT_COMPLETE');
    await file.delete();
  });
}
