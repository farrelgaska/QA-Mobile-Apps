import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/features/reports/screens/report_detail_screen.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_checklist_answer_model.dart';
import 'package:mobile/shared/models/qc_report_model.dart';

void main() {
  test(
    'newer local draft survives API merge and resolves values by item ID',
    () {
      final state = DummyState();
      final originalReports = List<QCReportModel>.from(state.reports);
      addTearDown(() {
        state.reports
          ..clear()
          ..addAll(originalReports);
      });

      QCChecklistAnswer answer(String id, String value, String inputType) =>
          QCChecklistAnswer(
            itemId: id,
            value: value,
            status: QCResultStatus.notFilled,
            photoPaths: [],
            paramName: id,
            standardText: 'Standard $id',
            inputType: inputType,
          );

      final localDraft = QCReportModel(
        id: 'QC-MAT-2026-1009',
        title: 'Fresh local draft',
        type: QCType.material,
        status: QCReportStatus.DRAFT,
        staffNote: '',
        submittedAt: DateTime.utc(2026, 7, 17, 10),
        checklistItems: [
          answer('number-1', '12333', 'number'),
          answer('boolean-1', 'Ya', 'boolean'),
          answer('choice-1', 'Sesuai', 'choice'),
          answer('text-1', 'Permukaan baik', 'text'),
        ],
      );
      final staleServerReport = localDraft.copyWith(
        title: 'Older server report',
        submittedAt: DateTime.utc(2026, 7, 17, 9),
        checklistItems: [
          answer('number-1', '12333', 'number'),
          answer('boolean-1', '', 'boolean'),
          answer('choice-1', '', 'choice'),
          answer('text-1', '', 'text'),
        ],
      );

      state.reports
        ..clear()
        ..add(localDraft);

      expect(localDraft.checklistItems[1].itemId, 'boolean-1');
      expect(localDraft.checklistItems[1].value, 'Ya');

      state.mergeReportsFromApi([staleServerReport]);
      final retrieved = state.reports.single;
      final retrievedById = {
        for (final item in retrieved.checklistItems) item.itemId: item.value,
      };
      expect(retrievedById['number-1'], '12333');
      expect(retrievedById['boolean-1'], 'Ya');

      final detailById = {
        for (final item in resolveReportDetailItems(retrieved))
          item.itemId!: item.value,
      };
      expect(detailById, {
        'number-1': '12333',
        'boolean-1': 'Ya',
        'choice-1': 'Sesuai',
        'text-1': 'Permukaan baik',
      });
    },
  );
}
