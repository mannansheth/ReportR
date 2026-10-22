import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' as flutter;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/ui_strings.dart';
import '../models/report.dart';

class PdfService {
  Future<String> generate({
    required ReportDraft report,
    required String imagePath,
    required String outputPath,
    String languageCode = 'en',
  }) async {
    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw const FileSystemException('Report image is missing.');
    }
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw const FileSystemException('Report image is empty.');
    }
    final strings = UiStrings(languageCode);
    await initializeDateFormatting(languageCode);
    final created = DateTime.parse(report.createdDate).toLocal();
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/DMSans.ttf'));
    final document = pw.Document(
      title: 'ReportR - ${report.reportID}',
      author: 'ReportR',
    );
    final image = pw.MemoryImage(bytes);
    const ink = PdfColor.fromInt(0xFF12364B);
    const muted = PdfColor.fromInt(0xFF526477);
    const line = PdfColor.fromInt(0xFFE0E6ED);
    const contentWidth = 507.0;
    Future<pw.Widget> text(
      String value, {
      double width = contentWidth,
      double size = 11,
      PdfColor color = ink,
    }) => _text(value, font, width: width, size: size, color: color);
    Future<pw.Widget> field(
      String label,
      String value, {
      double width = contentWidth,
    }) async => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        await text(strings.text(label), width: width, size: 9, color: muted),
        pw.SizedBox(height: 5),
        await text(
          value.isEmpty ? strings.text('Not provided') : value,
          width: width,
        ),
      ],
    );
    final heading = await text(strings.text('Civic issue report'), size: 20);
    final date = await text(
      DateFormat('d MMM yyyy, h:mm a', languageCode).format(created),
      size: 10,
      color: muted,
    );
    final reporter = await field('Reported by', report.name, width: 244);
    final phone = await field('Phone number', report.number, width: 244);
    final category = await field(
      'Reported issues',
      strings.category(report.category),
    );
    final description = await field('Description', report.description);
    final location = await field('Location', report.location.readableLocation);
    final evidence = await text(strings.text('Photo evidence'), size: 13);
    final coordinates = await text(
      '${strings.text('Coordinates')}: ${report.location.latitude.toStringAsFixed(6)}, ${report.location.longitude.toStringAsFixed(6)}',
      size: 10,
      color: muted,
    );
    final notice = await text(
      strings.text(
        'Keep this copy for your records. Track updates in the ReportR app.',
      ),
      size: 9,
      color: muted,
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(44),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ReportR',
              style: pw.TextStyle(
                font: font,
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.SizedBox(height: 8),
            heading,
            pw.SizedBox(height: 8),
            date,
            pw.SizedBox(height: 16),
            pw.Divider(color: line),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                report.reportID,
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF1F5F9),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              report.reportID,
              style: pw.TextStyle(
                fontSize: 12,
                color: ink,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: 244, child: reporter),
              pw.SizedBox(width: 19),
              pw.SizedBox(width: 244, child: phone),
            ],
          ),
          pw.SizedBox(height: 20),
          category,
          pw.SizedBox(height: 18),
          description,
          pw.SizedBox(height: 20),
          evidence,
          pw.SizedBox(height: 8),
          pw.Container(
            width: contentWidth,
            height: 220,
            alignment: pw.Alignment.center,
            color: const PdfColor.fromInt(0xFFF1F5F9),
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 18),
          location,
          pw.SizedBox(height: 8),
          coordinates,
          pw.SizedBox(height: 18),
          pw.Divider(color: line),
          notice,
        ],
      ),
    );
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await document.save(), flush: true);
    return file.path;
  }

  /// Indic text is shaped by Flutter, then embedded at print resolution. This
  /// preserves conjuncts and matras that PDF-only glyph layout cannot shape.
  Future<pw.Widget> _text(
    String value,
    pw.Font font, {
    required double width,
    required double size,
    required PdfColor color,
  }) async {
    final clean = cleanText(value);
    if (!RegExp(r'[^\x00-\x7F]').hasMatch(clean)) {
      return pw.Text(
        clean,
        style: pw.TextStyle(font: font, fontSize: size, color: color),
      );
    }
    final painter = flutter.TextPainter(
      text: flutter.TextSpan(
        text: clean,
        style: flutter.TextStyle(
          fontFamily: 'ReportDevanagari',
          fontFamilyFallback: const ['ReportSans'],
          fontSize: size,
          color: flutter.Color.fromARGB(
            255,
            (color.red * 255).round(),
            (color.green * 255).round(),
            (color.blue * 255).round(),
          ),
          height: 1.45,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(3);
    painter.paint(canvas, ui.Offset.zero);
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(
      (painter.width * 3).ceil().clamp(1, 10000),
      (painter.height * 3).ceil().clamp(1, 10000),
    );
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final height = painter.height;
    final actualWidth = painter.width;
    rendered.dispose();
    picture.dispose();
    painter.dispose();
    return pw.Image(
      pw.MemoryImage(data!.buffer.asUint8List()),
      width: actualWidth,
      height: height,
      alignment: pw.Alignment.centerLeft,
    );
  }

  static String cleanText(String text) =>
      text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '').trim();

  static Future<Uint8List> loadTemplateBytes() async {
    final data = await rootBundle.load('assets/templates/report_template.pdf');
    return data.buffer.asUint8List();
  }
}
