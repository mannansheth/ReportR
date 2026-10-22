import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/core/network/api_client.dart';
import 'package:reportr_flutter/services/report_service.dart';

class ReportClient extends ApiClient {
  ReportClient(this.response);
  dynamic response;
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<dynamic> postJsonValue(String path, Map<String, dynamic> body) async {
    this.path = path;
    this.body = body;
    return response;
  }
}

void main() {
  test('user reports carry user ID and decode SQL JSON location', () async {
    final client = ReportClient([{'Rid': 'r1', 'userID': 42, 'issue': 'Pothole', 'location': '{"lat":19.1,"lng":72.8}'}]);
    final reports = await ReportService(client).getUserReports('42');
    expect(client.path, 'api/reports/getUserReports');
    expect(client.body, {'userID': '42'});
    expect(reports.single.latitude, 19.1);
  });

  test('backend errors are surfaced rather than parsed as reports', () async {
    final service = ReportService(ReportClient({'success': false, 'message': 'Your session has expired.'}));
    await expectLater(service.getUserReports('42'), throwsA(isA<ReportServiceException>().having((error) => error.message, 'message', 'Your session has expired.')));
    await expectLater(service.getReportDetails(reportId: 'r1', userId: '42'), throwsA(isA<ReportServiceException>()));
    await expectLater(service.getStatusHistory(reportId: 'r1'), throwsA(isA<ReportServiceException>()));
  });

  test('empty reports and history are valid', () async {
    final service = ReportService(ReportClient([]));
    expect(await service.getUserReports('42'), isEmpty);
    expect(await service.getStatusHistory(reportId: 'r1'), isEmpty);
  });
}
