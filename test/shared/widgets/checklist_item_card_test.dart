import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/template_choice_option.dart';
import 'package:mobile/shared/widgets/checklist_item_card.dart';

Future<void> _pumpNumericCard(
  WidgetTester tester, {
  required String value,
  required QCResultStatus status,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
          currentStatus: status,
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

  group('parameter status badge', () {
    testWidgets('shows compliant status with icon at 320 px', (tester) async {
      await _pumpNumericCard(
        tester,
        value: '125',
        status: QCResultStatus.pass,
      );
      expect(find.text('Sesuai Standar'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byKey(const Key('parameter-status-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows non-compliant status and issue input', (tester) async {
      await _pumpNumericCard(
        tester,
        value: '130',
        status: QCResultStatus.fail,
      );
      expect(find.text('Tidak Sesuai Standar'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Keterangan Masalah *'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows neutral Belum Diisi status', (tester) async {
      await _pumpNumericCard(
        tester,
        value: '',
        status: QCResultStatus.notFilled,
      );
      expect(find.text('Belum Diisi'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    });
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

  testWidgets('PASS status hides issue description', (
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
            currentStatus: QCResultStatus.pass,
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

  testWidgets('FAIL status displays issue description', (
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
            currentStatus: QCResultStatus.fail,
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
              currentStatus: result == 'PASS_VALUE'
                  ? QCResultStatus.pass
                  : QCResultStatus.fail,
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

  testWidgets('text parameter provides explicit manual Staff status at 320 px',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var status = QCResultStatus.notFilled;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ChecklistItemCard(
              itemNumber: 1,
              title: 'Catatan visual',
              standardText: 'Diperiksa oleh Staff',
              inputType: QCInputType.text,
              currentStatus: status,
              resultValue: 'Permukaan tergores',
              issueDescription: '',
              photos: const [],
              isLocked: false,
              onStatusChanged: (value) => setState(() => status = value),
              onResultValueChanged: (_) {},
              onIssueDescriptionChanged: (_) {},
              onAddPhoto: () {},
              onDeletePhoto: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Status Pemeriksaan Staff *'), findsOneWidget);
    expect(find.text('Belum Diisi'), findsOneWidget);
    await tester.tap(find.text('Tidak Sesuai Standar'));
    await tester.pump();
    expect(status, QCResultStatus.fail);
    expect(find.text('Keterangan Masalah *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
