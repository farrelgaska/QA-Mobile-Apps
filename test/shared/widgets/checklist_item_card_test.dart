import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/template_choice_option.dart';
import 'package:mobile/shared/widgets/checklist_item_card.dart';

Future<void> _pumpNumericCard(
  WidgetTester tester, {
  required String value,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChecklistItemCard(
          itemNumber: 1,
          title: 'Diameter ruas atas',
          standardText: '122 - 128 mm',
          inputType: QCInputType.number,
          unit: 'mm',
          minValue: 122,
          maxValue: 128,
          currentStatus: QCResultStatus.notFilled,
          resultValue: value,
          issueDescription: '',
          photos: const [],
          isLocked: false,
          onStatusChanged: (_) {},
          onResultValueChanged: (_) {},
          onIssueDescriptionChanged: (_) {},
          onAddPhoto: () {},
          onDeletePhoto: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  const customOptions = [
    TemplateChoiceOption(
      id: 'pass',
      label: 'Rapi',
      value: 'PASS_VALUE',
      outcome: 'PASS',
      position: 0,
    ),
    TemplateChoiceOption(
      id: 'fail',
      label: 'Berantakan',
      value: 'FAIL_VALUE',
      outcome: 'FAIL',
      position: 1,
    ),
  ];

  group('numeric standard compliance indicator', () {
    final compliantValues = <String, String>{
      'minimum boundary': '122',
      'in range': '125',
      'maximum boundary': '128',
    };
    for (final scenario in compliantValues.entries) {
      testWidgets('${scenario.key} is compliant', (tester) async {
        await _pumpNumericCard(tester, value: scenario.value);

        expect(find.text('Sesuai Standar'), findsOneWidget);
        expect(find.text('Tidak Sesuai Standar'), findsNothing);
        expect(find.text('Standar: 122 - 128 mm'), findsOneWidget);
        final indicator = tester.widget<Container>(
          find.byKey(const Key('numeric-standard-compliance')),
        );
        expect(
          (indicator.decoration! as BoxDecoration).color,
          AppColors.approvedBg,
        );
      });
    }

    final nonCompliantValues = <String, String>{
      'below minimum': '121.99',
      'above maximum': '128.01',
    };
    for (final scenario in nonCompliantValues.entries) {
      testWidgets('${scenario.key} is not compliant', (tester) async {
        await _pumpNumericCard(tester, value: scenario.value);

        expect(find.text('Tidak Sesuai Standar'), findsOneWidget);
        expect(find.text('Sesuai Standar'), findsNothing);
        final indicator = tester.widget<Container>(
          find.byKey(const Key('numeric-standard-compliance')),
        );
        expect(
          (indicator.decoration! as BoxDecoration).color,
          AppColors.rejectedBg,
        );
      });
    }

    for (final value in ['', 'bukan angka']) {
      testWidgets(
        '${value.isEmpty ? 'empty' : 'invalid'} input hides compliance',
        (tester) async {
          await _pumpNumericCard(tester, value: value);

          expect(find.text('Sesuai Standar'), findsNothing);
          expect(find.text('Tidak Sesuai Standar'), findsNothing);
        },
      );
    }
  });

  testWidgets('non-empty choice options take priority over legacy choices', (
    tester,
  ) async {
    String selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistItemCard(
            itemNumber: 1,
            title: 'Kondisi',
            standardText: 'Harus rapi',
            inputType: QCInputType.choice,
            choices: const ['Legacy Sesuai', 'Legacy Tidak Sesuai'],
            choiceOptions: const [
              TemplateChoiceOption(
                id: 'pass',
                label: 'Sudah Rapi',
                value: 'PASS',
                outcome: 'PASS',
                position: 0,
              ),
              TemplateChoiceOption(
                id: 'fail',
                label: 'Perlu Perbaikan',
                value: 'FAIL',
                outcome: 'FAIL',
                position: 1,
              ),
            ],
            currentStatus: QCResultStatus.notFilled,
            resultValue: '',
            issueDescription: '',
            photos: const [],
            isLocked: false,
            onStatusChanged: (_) {},
            onResultValueChanged: (value) => selected = value,
            onIssueDescriptionChanged: (_) {},
            onAddPhoto: () {},
            onDeletePhoto: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('PASS'), findsNothing);
    expect(find.text('Legacy Sesuai'), findsNothing);
    await tester.tap(find.text('Sudah Rapi'));
    expect(selected, 'PASS');
  });

  testWidgets('empty choice options fall back to ordered legacy choices', (
    tester,
  ) async {
    String selected = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistItemCard(
            itemNumber: 1,
            title: 'Kondisi',
            standardText: 'Harus sesuai',
            inputType: QCInputType.choice,
            choices: const ['Sesuai', 'Tidak Sesuai'],
            choiceOptions: const [],
            currentStatus: QCResultStatus.notFilled,
            resultValue: '',
            issueDescription: '',
            photos: const [],
            isLocked: false,
            onStatusChanged: (_) {},
            onResultValueChanged: (value) => selected = value,
            onIssueDescriptionChanged: (_) {},
            onAddPhoto: () {},
            onDeletePhoto: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Sesuai'), findsOneWidget);
    expect(find.text('Tidak Sesuai'), findsOneWidget);
    expect(find.textContaining('Opsi belum dikonfigurasi'), findsNothing);
    final labels = tester
        .widgetList<Text>(
          find.descendant(of: find.byType(Wrap), matching: find.byType(Text)),
        )
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(labels, ['Sesuai', 'Tidak Sesuai']);

    await tester.tap(find.text('Tidak Sesuai'));
    expect(selected, 'Tidak Sesuai');
  });

  testWidgets('empty legacy choice explains unavailable configuration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistItemCard(
            itemNumber: 1,
            title: 'Legacy',
            standardText: 'Legacy standard',
            inputType: QCInputType.choice,
            currentStatus: QCResultStatus.notFilled,
            resultValue: '',
            issueDescription: '',
            photos: const [],
            isLocked: false,
            onStatusChanged: (_) {},
            onResultValueChanged: (_) {},
            onIssueDescriptionChanged: (_) {},
            onAddPhoto: () {},
            onDeletePhoto: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Opsi belum dikonfigurasi'), findsOneWidget);
    expect(find.text('Pilih Opsi Kriteria'), findsNothing);
  });

  testWidgets('PASS hides issue description based on outcome, not label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistItemCard(
            itemNumber: 1,
            title: 'Kondisi',
            standardText: 'Harus rapi',
            inputType: QCInputType.choice,
            choiceOptions: customOptions,
            currentStatus: QCResultStatus.notFilled,
            resultValue: 'PASS_VALUE',
            issueDescription: '',
            photos: const [],
            isLocked: false,
            onStatusChanged: (_) {},
            onResultValueChanged: (_) {},
            onIssueDescriptionChanged: (_) {},
            onAddPhoto: () {},
            onDeletePhoto: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Rapi'), findsOneWidget);
    expect(find.text('Keterangan Masalah *'), findsNothing);
  });

  testWidgets('FAIL displays issue description based on custom outcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistItemCard(
            itemNumber: 1,
            title: 'Kondisi',
            standardText: 'Harus rapi',
            inputType: QCInputType.choice,
            choiceOptions: customOptions,
            currentStatus: QCResultStatus.notFilled,
            resultValue: 'FAIL_VALUE',
            issueDescription: '',
            photos: const [],
            isLocked: false,
            onStatusChanged: (_) {},
            onResultValueChanged: (_) {},
            onIssueDescriptionChanged: (_) {},
            onAddPhoto: () {},
            onDeletePhoto: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Berantakan'), findsOneWidget);
    expect(find.text('Keterangan Masalah *'), findsOneWidget);
  });

  testWidgets('switching FAIL to PASS clears stale issue description', (
    tester,
  ) async {
    var result = 'FAIL_VALUE';
    var issue = 'Foto tidak jelas';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ChecklistItemCard(
              itemNumber: 1,
              title: 'Kondisi',
              standardText: 'Harus rapi',
              inputType: QCInputType.choice,
              choiceOptions: customOptions,
              currentStatus: QCResultStatus.notFilled,
              resultValue: result,
              issueDescription: issue,
              photos: const [],
              isLocked: false,
              onStatusChanged: (_) {},
              onResultValueChanged: (value) => setState(() => result = value),
              onIssueDescriptionChanged: (value) =>
                  setState(() => issue = value),
              onAddPhoto: () {},
              onDeletePhoto: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Keterangan Masalah *'), findsOneWidget);
    await tester.tap(find.text('Rapi'));
    await tester.pump();

    expect(result, 'PASS_VALUE');
    expect(issue, isEmpty);
    expect(find.text('Keterangan Masalah *'), findsNothing);
  });
}
