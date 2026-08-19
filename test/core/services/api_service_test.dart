import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
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
  group('API base URL resolution', () {
    test('local Flutter Web defaults to localhost', () {
      expect(
        resolveApiBaseUrl(
          configuredBaseUrl: '',
          isWeb: true,
          isReleaseMode: false,
          isAndroid: false,
        ),
        'http://localhost:3002',
      );
    });

    test('Android emulator defaults to the host alias', () {
      expect(
        resolveApiBaseUrl(
          configuredBaseUrl: '',
          isWeb: false,
          isReleaseMode: false,
          isAndroid: true,
        ),
        'http://10.0.2.2:3002',
      );
    });

    test('production Web uses and normalizes configured HTTPS URL', () {
      expect(
        resolveApiBaseUrl(
          configuredBaseUrl: '  https://qa-mobile-api.example.com///  ',
          isWeb: true,
          isReleaseMode: true,
          isAndroid: false,
        ),
        'https://qa-mobile-api.example.com',
      );
    });

    test('production Web falls back to production backend URL when missing',
        () {
      expect(
        resolveApiBaseUrl(
          configuredBaseUrl: '',
          isWeb: true,
          isReleaseMode: true,
          isAndroid: false,
        ),
        'https://qa-mobile-api.vercel.app',
      );
    });
  });

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

  test(
    'fetchReports preserves structured general info and parses all reports',
    () async {
      final reports = [
        _reportJson(
          id: 'submitted-legacy',
          status: 'SUBMITTED',
          generalInfo: {
            'poNumber': 'PO-001',
            'nullableValue': null,
            'sampleCount': 4,
            'reviewRequested': true,
            'tolerances': [5, 10],
          },
        ),
        _reportJson(
          id: 'submitted-structured',
          status: 'SUBMITTED',
          generalInfo: {
            'qcEvidenceCaptureMetadata': {
              'reports/report-1/checklist/item-1/photo.jpg': {
                'capturedAt': '2026-07-29T10:30:00.000+07:00',
                'latitude': -6.2088,
                'longitude': 106.8456,
                'accuracyMeters': 3.25,
                'locationLabel': null,
              },
            },
          },
        ),
        _reportJson(id: 'follow-up-1', status: 'NEEDS_FOLLOW_UP'),
        _reportJson(id: 'follow-up-2', status: 'NEEDS_FOLLOW_UP'),
        _reportJson(id: 'approved-1', status: 'APPROVED'),
      ];
      final service = ApiService.withClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode(reports),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
      );

      final parsed = await service.fetchReports();

      expect(parsed, hasLength(5));
      expect(
        parsed.where((report) => report.status == QCReportStatus.SUBMITTED),
        hasLength(2),
      );
      expect(
        parsed.where(
          (report) => report.status == QCReportStatus.NEEDS_FOLLOW_UP,
        ),
        hasLength(2),
      );
      expect(
        parsed.where((report) => report.status == QCReportStatus.APPROVED),
        hasLength(1),
      );
      final legacy = parsed.first;
      expect(legacy.generalInfo['poNumber'], 'PO-001');
      expect(legacy.generalInfo['nullableValue'], isNull);
      expect(legacy.generalInfo['sampleCount'], 4);
      expect(legacy.generalInfo['reviewRequested'], isTrue);
      expect(legacy.generalInfo['tolerances'], [5, 10]);

      final metadata = parsed[1].generalInfo['qcEvidenceCaptureMetadata']
          as Map<String, dynamic>;
      expect(
        metadata['reports/report-1/checklist/item-1/photo.jpg'],
        isA<Map>(),
      );
    },
  );

  test('API offline clears stale reports and exposes an error state', () async {
    final state = DummyState();
    final originalReports = List<QCReportModel>.from(state.reports);
    final originalError = state.reportsLoadError;
    state.reports = [_report()];
    addTearDown(() {
      state.reports = originalReports;
      state.reportsLoadError = originalError;
    });
    final service = ApiService.withClient(
      MockClient((_) async => throw http.ClientException('offline')),
    );

    await expectLater(
      state.fetchReportsFromApi(apiService: service),
      throwsA(isA<ApiRequestException>()),
    );

    expect(state.reports, isEmpty);
    expect(state.reportsLoadError, contains('tidak dapat dimuat'));
  });
}

Map<String, dynamic> _reportJson({
  required String id,
  required String status,
  Map<String, dynamic> generalInfo = const {},
}) =>
    {
      'id': id,
      'title': id,
      'type': 'MATERIAL',
      'status': status,
      'staff': {'name': 'Staff Warehouse', 'nik': 'NIK-1'},
      'location': {
        'site_id': 'site-1',
        'site_name': 'Gudang',
        'area': 'Area',
        'detail_location': '',
      },
      'general_info': generalInfo,
      'checklist_items': <dynamic>[],
      'staff_note': '',
      'submitted_at': '2026-07-29T10:30:00.000Z',
      'admin_review': <String, dynamic>{},
      'general_photos': <String>[],
      'samples': <dynamic>[],
    };
