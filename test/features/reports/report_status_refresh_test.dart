import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_report_model.dart';
import 'package:mobile/shared/widgets/status_badge.dart';

const _reportId = 'QC-MAT-STATUS-REFRESH';

Map<String, dynamic> _reportPayload(
  String status, {
  Map<String, String> generalInfo = const {},
}) {
  return {
    'id': _reportId,
    'title': 'Status refresh regression',
    'type': 'MATERIAL',
    'status': status,
    'staff': {'name': 'Staff Warehouse', 'nik': 'STAFF-01'},
    'location': {
      'site_id': 'site-1',
      'site_name': 'Gudang',
      'area': 'Area A',
      'detail_location': 'Bay 1',
    },
    'general_info': generalInfo,
    'staff_note': '',
    'submitted_at': '2026-07-27T03:49:55.044Z',
    'admin_review': status == 'NEEDS_FOLLOW_UP'
        ? {
            'admin_note': 'Ulangi pemeriksaan dimensi.',
            'reviewed_at': '2026-07-27T04:00:00.000Z',
            'conclusion': 'NOT_PASSED',
          }
        : {},
    'sample_count': 1,
    'samples': [
      {
        'id': 'sample-1',
        'sample_number': 1,
        'inspection_status': 'COMPLETED',
        'checklist_answers': [
          {
            'checklist_item_id': 'dimension',
            'input_type': 'number',
            'actual_value': 8,
            'note': 'Catatan Staff tetap ada.',
            'evaluation_status': 'OUT_OF_STANDARD',
            'admin_evaluation': 'FAIL',
            'admin_note': 'Ukur ulang parameter ini.',
          },
        ],
        'notes': 'Catatan sampel',
        'photo_paths': <String>[],
        'created_at': '2026-07-27T03:40:00.000Z',
        'updated_at': '2026-07-27T04:00:00.000Z',
      },
    ],
  };
}

QCReportModel _localReport(QCReportStatus status) => QCReportModel(
      id: _reportId,
      title: 'Stale local report',
      type: QCType.material,
      status: status,
      staffNote: '',
    );

void main() {
  group('QC report workflow status presentation', () {
    for (final entry in {
      QCReportStatus.DRAFT: 'Draft',
      QCReportStatus.SUBMITTED: 'Dikirim',
      QCReportStatus.NEEDS_FOLLOW_UP: 'Perlu Tindak Lanjut',
      QCReportStatus.APPROVED: 'Disetujui',
    }.entries) {
      testWidgets('${entry.key.name} renders ${entry.value}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StatusBadge(status: entry.key)),
          ),
        );

        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('sampling STOP metadata does not control workflow badge', (
      tester,
    ) async {
      final report = QCReportModel.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
            jsonEncode(
              _reportPayload(
                'SUBMITTED',
                generalInfo: const {
                  'qcSamplingDecision': 'STOP',
                  'qcSamplingStopReason': 'Dua sampel gagal.',
                },
              ),
            ),
          ),
        ),
      );

      expect(report.status, QCReportStatus.SUBMITTED);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StatusBadge(status: report.status)),
        ),
      );

      expect(find.text('Dikirim'), findsOneWidget);
      expect(find.text('Perlu Tindak Lanjut'), findsNothing);
    });

    testWidgets('parameter and active badges use canonical labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: QCResultStatus.pass),
                StatusBadge(status: QCResultStatus.fail),
                StatusBadge(status: 'Aktif'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Sesuai Standar'), findsOneWidget);
      expect(find.text('Tidak Sesuai Standar'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Lulus'), findsNothing);
    });
  });

  group('authoritative report detail refresh', () {
    late DummyState state;
    late List<QCReportModel> originalReports;

    setUp(() {
      state = DummyState();
      originalReports = List<QCReportModel>.from(state.reports);
      state.reports
        ..clear()
        ..add(_localReport(QCReportStatus.SUBMITTED));
    });

    tearDown(() {
      state.reports
        ..clear()
        ..addAll(originalReports);
    });

    test(
      'fetched NEEDS_FOLLOW_UP replaces stale SUBMITTED cache data',
      () async {
        final service = ApiService.withClient(
          MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/reports/$_reportId');
            expect(request.headers['Cache-Control'], 'no-cache');
            return http.Response(
              jsonEncode(_reportPayload('NEEDS_FOLLOW_UP')),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final refreshed = await state.fetchReportFromApi(
          _reportId,
          apiService: service,
        );

        expect(refreshed.status, QCReportStatus.NEEDS_FOLLOW_UP);
        expect(state.reports.single.status, QCReportStatus.NEEDS_FOLLOW_UP);
        expect(refreshed.adminNote, 'Ulangi pemeriksaan dimensi.');
        expect(
          refreshed.samples.single.checklistAnswers.single.adminNote,
          'Ukur ulang parameter ini.',
        );
        expect(
          refreshed.samples.single.checklistAnswers.single.issueNote,
          'Catatan Staff tetap ada.',
        );
      },
    );

    test('reopening refreshes a report whose backend status changed', () async {
      var requestCount = 0;
      final service = ApiService.withClient(
        MockClient((request) async {
          requestCount++;
          final status = requestCount == 1 ? 'SUBMITTED' : 'NEEDS_FOLLOW_UP';
          return http.Response(
            jsonEncode(_reportPayload(status)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await state.fetchReportFromApi(_reportId, apiService: service);
      expect(state.reports.single.status, QCReportStatus.SUBMITTED);

      await state.fetchReportFromApi(_reportId, apiService: service);
      expect(state.reports.single.status, QCReportStatus.NEEDS_FOLLOW_UP);
      expect(requestCount, 2);
    });
  });
}
