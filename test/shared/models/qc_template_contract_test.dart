import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_template_contract.dart';

void main() {
  test('parses number standard 4.2 without inferring a choice', () {
    final template = QCTemplateContract.material({
      'id': 'MAT-1',
      'name': 'Material',
      'form_code': 'MAT-FORM',
      'is_active': true,
      'checklist_items': [
        {
          'id': 'number-1',
          'parameter_name': 'Ketebalan',
          'input_type': 'number',
          'standard_text': '4.2',
          'min_value': null,
          'max_value': null,
          'is_required': true,
          'required_photo': false,
          'is_active': true,
          'choice_options': [],
        },
      ],
    });

    final item = template.checklistItems.single;
    expect(item.inputType, QCInputType.number);
    expect(item.standardText, '4.2');
    expect(item.minValue, isNull);
    expect(item.maxValue, isNull);
    expect(item.choiceOptions, isEmpty);
  });

  test('parses and orders structured custom choices', () {
    final template = QCTemplateContract.work({
      'id': 'WRK-1',
      'name': 'Work',
      'category': 'Construction',
      'is_active': true,
      'checklist_items': [
        {
          'id': 'choice-1',
          'parameter_name': 'Kondisi',
          'input_type': 'choice',
          'standard_text': 'Periksa kondisi',
          'is_required': true,
          'required_photo': true,
          'is_active': true,
          'choice_options': [
            {'id': 'fail', 'label': 'Perlu Perbaikan', 'value': 'FAIL', 'outcome': 'FAIL', 'position': 1},
            {'id': 'pass', 'label': 'Sudah Rapi', 'value': 'PASS', 'outcome': 'PASS', 'position': 0},
          ],
        },
      ],
    });

    final item = template.checklistItems.single;
    expect(item.inputType, InputType.choice);
    expect(item.choiceOptions.map((option) => option.label),
        ['Sudah Rapi', 'Perlu Perbaikan']);
    expect(item.required, isTrue);
    expect(item.requiredPhoto, isTrue);
  });
}
