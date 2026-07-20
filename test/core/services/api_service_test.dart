import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_report_model.dart';

QCReportModel _report() => QCReportModel(
  id: 'QC-REPORT-2026-0001',
  title: 'Report submission test',
  type: QCType.material,
  status: QCReportStatus.SUBMITTED,
  staffNote: '',
);

void main() {
  test('HTTP 201 is a successful report create', () async {
    var postCount = 0;
    final service = ApiService.withClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        postCount++;
        return http.Response('', 201);
      }),
    );

    expect(await service.postReport(_report(), throwOnError: true), isTrue);
    expect(postCount, 1);
  });

  test('ambiguous POST failure reconciles an existing report', () async {
    var postCount = 0;
    var getCount = 0;
    final report = _report();
    final service = ApiService.withClient(
      MockClient((request) async {
        if (request.method == 'POST') {
          postCount++;
          throw TimeoutException('response was not received');
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/reports/${report.id}');
        getCount++;
        return http.Response('{}', 200);
      }),
    );

    expect(await service.postReport(report, throwOnError: true), isTrue);
    expect(postCount, 1);
    expect(getCount, 1);
  });

  test('direct HTTP 409 remains a conflict error', () async {
    var postCount = 0;
    final report = _report();
    final service = ApiService.withClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        postCount++;
        return http.Response('', 409);
      }),
    );

    await expectLater(
      service.postReport(report, throwOnError: true),
      throwsA(
        isA<ApiRequestException>().having(
          (error) => error.message,
          'message',
          contains('sudah tersimpan'),
        ),
      ),
    );
    expect(postCount, 1);
  });
}
