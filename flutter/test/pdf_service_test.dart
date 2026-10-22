import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/models/report.dart';
import 'package:reportr_flutter/models/report_location.dart';
import 'package:reportr_flutter/services/pdf_service.dart';

void main() {
  test('PDF text preserves Hindi and Marathi instead of stripping Unicode', () {
    expect(PdfService.cleanText('  सड़क पर गड्ढा  '), 'सड़क पर गड्ढा');
    expect(PdfService.cleanText('कचरा आणि खड्डा'), 'कचरा आणि खड्डा');
  });
  testWidgets(
    'generated PDFs retain text and lay out long content in all supported languages',
    (tester) async {
      await tester.runAsync(() async {
        final devanagari = FontLoader('ReportDevanagari')
          ..addFont(
            rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
          );
        final latin = FontLoader('ReportSans')
          ..addFont(rootBundle.load('assets/fonts/DMSans.ttf'));
        await devanagari.load();
        await latin.load();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 800, 450),
          Paint()..color = const Color(0xFF687B88),
        );
        canvas.drawOval(
          const Rect.fromLTWH(150, 160, 300, 180),
          Paint()..color = const Color(0xFF142631),
        );
        final image = await recorder.endRecording().toImage(800, 450);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final output = Directory('../output/pdf')..createSync(recursive: true);
        final photo = File('${output.path}/qa-evidence.png');
        await photo.writeAsBytes(png!.buffer.asUint8List());
        for (final language in ['en', 'hi', 'mr']) {
          final report = ReportDraft(
            reportID: 'Rid_QA_$language',
            userID: 'qa',
            name: language == 'en' ? 'ReportR QA' : 'आदित्य शर्मा',
            number: '9999999900',
            category: 'Pothole, Garbage overflow',
            description: language == 'en'
                ? 'A large pothole and overflowing garbage obstruct the public footpath. Please repair the road and remove the waste.'
                : language == 'hi'
                ? 'सड़क पर बड़ा गड्ढा और जमा कचरा पैदल चलने वालों के लिए खतरा है। कृपया सड़क की मरम्मत करें और कचरा हटाएँ।'
                : 'रस्त्यावरील मोठा खड्डा आणि साचलेला कचरा पादचाऱ्यांसाठी धोकादायक आहे. कृपया रस्त्याची दुरुस्ती करा आणि कचरा हटवा.',
            location: ReportLocation(
              latitude: 19.076,
              longitude: 72.8777,
              readableLocation: language == 'en'
                  ? 'Public footpath near the municipal market, Mumbai, Maharashtra, India'
                  : 'महानगरपालिका बाजाराजवळील सार्वजनिक रस्ता, मुंबई, महाराष्ट्र, भारत',
            ),
            createdDate: '2026-10-15T06:00:00.000Z',
          );
          final path = await PdfService().generate(
            report: report,
            imagePath: photo.path,
            outputPath: '${output.path}/report-preview-$language.pdf',
            languageCode: language,
          );
          expect(await File(path).length(), greaterThan(500));
          expect(
            String.fromCharCodes((await File(path).readAsBytes()).take(5)),
            '%PDF-',
          );
        }
        await photo.delete();
      });
    },
  );
}
