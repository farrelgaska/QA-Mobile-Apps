import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/template_choice_option.dart';
import 'package:mobile/shared/widgets/checklist_item_card.dart';

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

  testWidgets('choice displays custom label and stores canonical value', (
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
    await tester.tap(find.text('Sudah Rapi'));
    expect(selected, 'PASS');
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
