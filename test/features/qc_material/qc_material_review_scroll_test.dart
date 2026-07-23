import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/qc_material/screens/qc_material_form_screen.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/qc_material_evaluation_model.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';
import 'package:provider/provider.dart';

QCMaterialTemplate _template() => QCMaterialTemplate(
  id: 'MAT-REVIEW-SCROLL',
  name: 'Review Scroll',
  code: 'MAT-SCROLL',
  description: '',
  checklistItems: [
    QCChecklistItem(
      id: 'condition',
      label: 'Kondisi',
      category: 'Visual',
      inputType: QCInputType.booleanCheck,
      standardText: 'Sesuai',
      required: true,
    ),
    ...List.generate(
      7,
      (index) => QCChecklistItem(
        id: 'optional-$index',
        label: 'Catatan Opsional ${index + 1}',
        category: 'Tambahan',
        inputType: QCInputType.text,
        standardText: '',
        required: false,
      ),
    ),
  ],
);

void _fillGeneralInformation(
  QCMaterialFormProvider provider, {
  required int sampleCount,
}) {
  provider.poNumberController.text = 'PO-SCROLL';
  provider.poDateController.text = '2026-07-01';
  provider.doNumberController.text = 'DO-SCROLL';
  provider.vendorNameController.text = 'Vendor';
  provider.materialIdController.text = 'MAT-REVIEW-SCROLL';
  provider.arrivalVolumeController.text = '100';
  provider.samplingVolumeController.text = '$sampleCount';
  provider.sampleCountController.text = '$sampleCount';
  provider.brandNameController.text = 'Brand';
  provider.warehouseLocationController.text = 'Gudang';
  provider.stelVersionController.text = 'STEL-SCROLL';
  provider.qaExpiryDateController.text = '2028-12-31';
  provider.tkdnNumberController.text = 'TKDN-SCROLL';
  provider.tkdnCertDateController.text = '2026-01-15';
  provider.tkdnValueController.text = '45';
}

Future<QCMaterialFormProvider> _pumpFirstSample(
  WidgetTester tester, {
  int sampleCount = 3,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: QCMaterialFormScreen(
        materialId: 'MAT-REVIEW-SCROLL',
        template: _template(),
      ),
    ),
  );
  final nextButton = find.byKey(const Key('qc_material_next_button'));
  final provider = Provider.of<QCMaterialFormProvider>(
    tester.element(nextButton),
    listen: false,
  );
  _fillGeneralInformation(provider, sampleCount: sampleCount);
  await tester.ensureVisible(nextButton);
  await tester.tap(nextButton);
  await tester.pumpAndSettle();
  expect(provider.currentStep, 1);
  return provider;
}

ScrollController _formScrollController(WidgetTester tester) {
  return tester
      .widget<SingleChildScrollView>(
        find.byKey(const Key('qc_material_form_scroll')),
      )
      .controller!;
}

Future<void> _scrollNextButtonIntoView(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('qc_material_next_button')));
  await tester.pump();
  expect(_formScrollController(tester).position.pixels, greaterThan(0));
}

void _makeTwoSamplesOutOfStandard(QCMaterialFormProvider provider) {
  provider.samples[0].answers[0].value = 'Ya';
  provider.samples[1].answers[0].value = 'Ya';
  provider.setParameterEvaluationStatus(
    sampleIndex: 0,
    answerIndex: 0,
    status: QCSampleEvaluationStatus.outOfStandard,
  );
  provider.setParameterEvaluationStatus(
    sampleIndex: 1,
    answerIndex: 0,
    status: QCSampleEvaluationStatus.outOfStandard,
  );
}

void main() {
  testWidgets('successful Next scrolls the form to the top', (tester) async {
    final provider = await _pumpFirstSample(tester, sampleCount: 2);
    provider.updateAnswer(0, 'Ya');
    await _scrollNextButtonIntoView(tester);

    await tester.tap(find.byKey(const Key('qc_material_next_button')));
    await tester.pumpAndSettle();

    expect(provider.currentStep, 2);
    expect(_formScrollController(tester).position.pixels, 0);
    expect(provider.samples[0].answers[0].value, 'Ya');
  });

  testWidgets(
    'new eligibility scrolls to warning and highlights it only once',
    (tester) async {
      final provider = await _pumpFirstSample(tester);
      _makeTwoSamplesOutOfStandard(provider);
      await tester.pump();
      await _scrollNextButtonIntoView(tester);

      await tester.tap(find.byKey(const Key('qc_material_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(provider.currentStep, 2);
      expect(
        find.byKey(const Key('qc_material_review_warning_highlight')),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(_formScrollController(tester).position.pixels, 0);
      final warningRect = tester.getRect(
        find.byKey(const Key('qc_material_review_request_card')),
      );
      expect(warningRect.top, greaterThanOrEqualTo(0));
      expect(
        warningRect.bottom,
        lessThanOrEqualTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('qc_material_review_warning_highlight')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('qc_material_review_warning_idle')),
        findsOneWidget,
      );

      await _scrollNextButtonIntoView(tester);
      await tester.tap(find.byKey(const Key('qc_material_next_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(provider.currentStep, 3);
      expect(
        find.byKey(const Key('qc_material_review_warning_highlight')),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(_formScrollController(tester).position.pixels, 0);
    },
  );

  testWidgets('disposing during delayed post-navigation scroll is safe', (
    tester,
  ) async {
    final provider = await _pumpFirstSample(tester, sampleCount: 2);
    provider.updateAnswer(0, 'Ya');
    await _scrollNextButtonIntoView(tester);

    await tester.tap(find.byKey(const Key('qc_material_next_button')));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
