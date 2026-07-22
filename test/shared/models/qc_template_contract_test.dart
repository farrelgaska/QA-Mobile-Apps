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

  test('parses canonical and legacy material boolean input types', () {
    Map<String, dynamic> materialWithInputType(String inputType) => {
      'id': 'MAT-BOOLEAN',
      'name': 'Material boolean',
      'form_code': 'MAT-BOOLEAN',
      'is_active': true,
      'checklist_items': [
        {
          'id': 'boolean-1',
          'parameter_name': 'Kondisi fisik',
          'input_type': inputType,
          'standard_text': 'OK',
          'category': '',
          'min_value': null,
          'max_value': null,
          'validation_rule': {
            'type': 'booleanRequired',
            'min_value': null,
            'max_value': null,
          },
          'is_required': true,
          'required_photo': false,
          'is_active': true,
          'choice_options': [],
        },
      ],
    };

    expect(
      QCTemplateContract.material(
        materialWithInputType('boolean'),
      ).checklistItems.single.inputType,
      QCInputType.booleanCheck,
    );
    expect(
      QCTemplateContract.material(
        materialWithInputType('booleanCheck'),
      ).checklistItems.single.inputType,
      QCInputType.booleanCheck,
    );
  });

  test('falls back to legacy choices when structured options are empty', () {
    final template = QCTemplateContract.material({
      'id': 'MAT-LEGACY-CHOICE',
      'name': 'Material legacy choice',
      'form_code': 'MAT-LEGACY-CHOICE',
      'is_active': true,
      'checklist_items': [
        {
          'id': 'paint-color',
          'parameter_name': 'Warna cat sesuai standar pengecatan',
          'input_type': 'choice',
          'standard_text': 'Sesuai',
          'choices': ['Sesuai', 'Tidak Sesuai'],
          'choice_options': [],
          'is_required': true,
          'required_photo': false,
          'is_active': true,
        },
      ],
    });

    final options = template.checklistItems.single.choiceOptions;
    expect(template.checklistItems.single.choices, ['Sesuai', 'Tidak Sesuai']);
    expect(options.map((option) => option.label), ['Sesuai', 'Tidak Sesuai']);
    expect(options.map((option) => option.value), ['Sesuai', 'Tidak Sesuai']);
    expect(options.map((option) => option.outcome), ['PASS', 'FAIL']);
  });

  test('falls back to legacy choices when structured options are missing', () {
    final template = QCTemplateContract.work({
      'id': 'WRK-LEGACY-CHOICE',
      'name': 'Work legacy choice',
      'category': 'Construction',
      'is_active': true,
      'checklist_items': [
        {
          'id': 'condition',
          'parameter_name': 'Kondisi',
          'input_type': 'choice',
          'standard_text': 'Sesuai',
          'choices': ['Baik', 'Perlu Perbaikan'],
          'is_required': true,
          'required_photo': false,
          'is_active': true,
        },
      ],
    });

    final item = template.checklistItems.single;
    expect(item.choices, ['Baik', 'Perlu Perbaikan']);
    expect(item.choiceOptions.map((option) => option.label), [
      'Baik',
      'Perlu Perbaikan',
    ]);
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
          'choices': ['Legacy Sesuai', 'Legacy Tidak Sesuai'],
          'is_required': true,
          'required_photo': true,
          'is_active': true,
          'choice_options': [
            {
              'id': 'fail',
              'label': 'Perlu Perbaikan',
              'value': 'FAIL',
              'outcome': 'FAIL',
              'position': 1,
            },
            {
              'id': 'pass',
              'label': 'Sudah Rapi',
              'value': 'PASS',
              'outcome': 'PASS',
              'position': 0,
            },
          ],
        },
      ],
    });

    final item = template.checklistItems.single;
    expect(item.inputType, InputType.choice);
    expect(item.choiceOptions.map((option) => option.label), [
      'Sudah Rapi',
      'Perlu Perbaikan',
    ]);
    expect(
      item.choiceOptions.map((option) => option.label),
      isNot(contains('Legacy Sesuai')),
    );
    expect(item.required, isTrue);
    expect(item.requiredPhoto, isTrue);
  });
}
