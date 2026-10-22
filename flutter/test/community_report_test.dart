import 'package:flutter_test/flutter_test.dart';
import 'package:reportr_flutter/models/community_report.dart';

void main() {
  test(
    'public DTO excludes identities and private attachments, preserves evidence state',
    () {
      final report = CommunityReport.fromJson({
        'Rid': 'r1',
        'issue': 'Pothole',
        'location': {'lat': '19.1', 'lng': '72.8'},
        'userID': 'private-owner',
        'pdfURL': 'private.pdf',
        'audioURL': 'private.m4a',
        'myEvidenceState': 'pending',
        'resolutionVotedByMe': true,
        'resolutionWeight': 3,
        'resolutionVoters': 1,
      });
      expect(report.resolutionProgress, .6);
      expect(report.myEvidenceState, 'pending');
      expect(report.resolutionVotedByMe, true);
      expect(report.resolutionVerifiedPhoto, false);
      expect(() => (report as dynamic).pdfUrl, throwsNoSuchMethodError);
      expect(() => (report as dynamic).audioUrl, throwsNoSuchMethodError);
      expect(() => (report as dynamic).userId, throwsNoSuchMethodError);
    },
  );
  test(
    'community boundaries include 500/200 metres and reject outside/invalid values',
    () {
      expect(CommunityRange.canConfirm(500), true);
      expect(CommunityRange.canConfirm(500.001), false);
      expect(CommunityRange.canResolve(200), true);
      expect(CommunityRange.canResolve(200.001), false);
      expect(CommunityRange.canConfirm(double.nan), false);
      expect(CommunityRange.canResolve(-1), false);
    },
  );
  test('public page parses pagination and resolved state', () {
    final page = CommunityPage.fromJson({
      'reports': [
        {
          'Rid': 'r1',
          'location': {'lat': 0, 'lng': 0},
          'status': 'Resolved',
          'resolutionWeight': 6,
        },
      ],
      'total': 21,
      'page': 2,
      'hasMore': false,
    });
    expect(page.reports.single.isResolved, true);
    expect(page.reports.single.resolutionProgress, 1);
    expect(page.total, 21);
    expect(page.page, 2);
  });
}
