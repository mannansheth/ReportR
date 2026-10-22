import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/models/report.dart';
import 'package:reportr_flutter/models/report_location.dart';
import 'package:reportr_flutter/services/report_upload_service.dart';

void main() {
  test('server duplicate race survives HTTP409 as an existing issue, not a generic upload error', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp('reportr-duplicate-http-');
    addTearDown(() async { await server.close(force: true); await directory.delete(recursive: true); });
    dotenv.loadFromString(envString: 'BACKEND_BASE_URL=http://127.0.0.1:${server.port}/');
    server.listen((request) async {
      expect(request.uri.path, '/api/user/submitReport');
      expect(request.headers.contentType?.mimeType, 'multipart/form-data');
      await request.drain<void>();
      request.response.statusCode = 409;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success':false,'code':'NEARBY_DUPLICATE','report':{'Rid':'Rid_existing','confirmationCount':5}}));
      await request.response.close();
    });
    final image = File('${directory.path}/photo.png');
    await image.writeAsBytes([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]);
    final pdf = File('${directory.path}/report.pdf'); await pdf.writeAsString('%PDF-1.4\n%%EOF');
    final result = await ReportUploadService(ApiClient(authToken:'fixture-token')).upload(
      report: const ReportDraft(reportID:'Rid_new',userID:'1',name:'Fixture',number:'9999999900',category:'Pothole',description:'Damaged road',location:ReportLocation(latitude:19,longitude:72,readableLocation:'Fixture road'),createdDate:'2026-10-15T06:00:00Z'),
      imagePath: image.path,pdfPath: pdf.path);
    expect(result.isSuccess, isFalse);
    expect(result.duplicateReport?['Rid'], 'Rid_existing');
    expect(result.duplicateReport?['confirmationCount'], 5);
  });
}
