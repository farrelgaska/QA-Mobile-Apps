import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/qc_validation_helper.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/models/template_choice_option.dart';

QCChecklistItem _item({
  required QCInputType type,
  double? min,
  double? max,
  List<TemplateChoiceOption> options = const [],
  List<String>? choices,
}) =>
    QCChecklistItem(
      id: 'parameter',
      label: 'Parameter',
      category: 'Test',
      inputType: type,
      standardText: 'Informasi standar',
      minValue: min,
      maxValue: max,
      choiceOptions: options,
      choices: choices,
    );

void main() {
  test('angka dalam structured bounds berstatus Sesuai Standar', () {
    final result = QCValidationHelper.validateChecklistAnswer(
      item: _item(type: QCInputType.number, min: -30, max: -10),
      value: '-20',
    );
    expect(result.status, QCResultStatus.pass);
    expect(result.isValid, isTrue);
  });

  test('angka di luar structured bounds berstatus Tidak Sesuai Standar', () {
    final result = QCValidationHelper.validateChecklistAnswer(
      item: _item(type: QCInputType.number, min: 9, max: 11),
      value: '12',
    );
    expect(result.status, QCResultStatus.fail);
    expect(result.isValid, isTrue);
  });

  test('choice memakai outcome PASS meskipun bukan opsi pertama', () {
    final result = QCValidationHelper.validateChecklistAnswer(
      item: _item(
        type: QCInputType.choice,
        options: const [
          TemplateChoiceOption(
            id: 'fail',
            label: 'Rusak',
            value: 'RUSAK',
            outcome: 'FAIL',
            position: 0,
          ),
          TemplateChoiceOption(
            id: 'pass',
            label: 'Baik',
            value: 'BAIK',
            outcome: 'PASS',
            position: 1,
          ),
        ],
      ),
      value: 'BAIK',
    );
    expect(result.status, QCResultStatus.pass);
  });

  test('choice memakai outcome FAIL tanpa menebak urutan', () {
    final result = QCValidationHelper.validateChecklistAnswer(
      item: _item(
        type: QCInputType.choice,
        options: const [
          TemplateChoiceOption(
            id: 'fail',
            label: 'Perlu perbaikan',
            value: 'REPAIR',
            outcome: 'FAIL',
            position: 0,
          ),
          TemplateChoiceOption(
            id: 'pass',
            label: 'Rapi',
            value: 'NEAT',
            outcome: 'PASS',
            position: 1,
          ),
        ],
      ),
      value: 'REPAIR',
    );
    expect(result.status, QCResultStatus.fail);
  });

  test('boolean legacy aman memetakan Ya dan Tidak', () {
    final item = _item(type: QCInputType.booleanCheck);
    expect(
      QCValidationHelper.validateChecklistAnswer(
        item: item,
        value: 'Ya',
      ).status,
      QCResultStatus.pass,
    );
    expect(
      QCValidationHelper.validateChecklistAnswer(
        item: item,
        value: 'Tidak',
      ).status,
      QCResultStatus.fail,
    );
  });

  test('text tidak dinilai otomatis dari isi', () {
    final result = QCValidationHelper.validateChecklistAnswer(
      item: _item(type: QCInputType.text),
      value: 'terlihat bagus',
    );
    expect(result.status, QCResultStatus.notFilled);
  });
}
