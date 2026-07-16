import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/models/template_choice_option.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';

void main() {
  test('material choice validation and stale note follow option outcome', () {
    final template = QCMaterialTemplate(
      id: 'MAT-CHOICE',
      name: 'Material choice',
      code: 'MAT-01',
      description: '',
      checklistItems: [
        QCChecklistItem(
          id: 'choice',
          label: 'Kondisi',
          category: 'Visual',
          inputType: QCInputType.choice,
          standardText: 'Harus rapi',
          choiceOptions: const [
            TemplateChoiceOption(
              id: 'pass',
              label: 'Rapi',
              value: 'CUSTOM_PASS',
              outcome: 'PASS',
              position: 0,
            ),
            TemplateChoiceOption(
              id: 'fail',
              label: 'Berantakan',
              value: 'CUSTOM_FAIL',
              outcome: 'FAIL',
              position: 1,
            ),
          ],
        ),
      ],
    );
    final provider = QCMaterialFormProvider()
      ..init(template.id, template: template);
    addTearDown(provider.dispose);

    provider.updateAnswer(0, 'CUSTOM_FAIL');
    expect(provider.validateForm(), contains('keterangan masalah'));

    provider.updateIssueNote(0, 'Kondisi berantakan');
    expect(provider.validateForm(), isNull);

    provider.updateAnswer(0, 'CUSTOM_PASS');
    expect(provider.answers.single.issueNote, isEmpty);
    expect(provider.validateForm(), isNull);
  });
}
