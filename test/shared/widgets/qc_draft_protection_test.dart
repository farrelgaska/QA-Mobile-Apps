import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/shared/services/qc_local_draft_store.dart';
import 'package:mobile/shared/widgets/qc_draft_protection.dart';

void main() {
  testWidgets('untouched form exits directly without a dialog', (tester) async {
    final store = _MemoryDraftStore();
    await _openForm(tester, store: store);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft_test_form')), findsNothing);
    expect(find.text('Simpan sebagai draft?'), findsNothing);
  });

  testWidgets('AppBar Back shows one guard and Cancel preserves values', (
    tester,
  ) async {
    final store = _MemoryDraftStore();
    await _openForm(tester, store: store);
    await tester.enterText(find.byKey(const Key('draft_test_input')), 'Isi QC');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan sebagai draft?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('qc_draft_cancel_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('draft_test_form')), findsOneWidget);
    expect(find.text('Isi QC'), findsOneWidget);
  });

  testWidgets('system Back saves the draft and exits', (tester) async {
    final store = _MemoryDraftStore();
    await _openForm(tester, store: store);
    final input = find.byKey(const Key('draft_test_input'));
    await tester.enterText(input, 'Simpan');
    final focusNode = tester
        .widget<EditableText>(
          find.descendant(of: input, matching: find.byType(EditableText)),
        )
        .focusNode;
    expect(focusNode.hasFocus, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isFalse);
    await tester.tap(find.byKey(const Key('qc_draft_save_button')));
    await tester.pumpAndSettle();

    expect(store.records['draft:test']?.payload['value'], 'Simpan');
    expect(find.byKey(const Key('draft_test_form')), findsNothing);
  });

  testWidgets('normal Navigator.pop uses the same guard', (tester) async {
    final store = _MemoryDraftStore();
    await _openForm(tester, store: store);
    await tester.enterText(find.byKey(const Key('draft_test_input')), 'Ubah');

    await tester.tap(find.byKey(const Key('draft_test_normal_pop')));
    await tester.pumpAndSettle();

    expect(find.text('Simpan sebagai draft?'), findsOneWidget);
  });

  testWidgets('Discard removes only the matching draft and exits', (
    tester,
  ) async {
    final store = _MemoryDraftStore();
    await store.write('draft:test', {'value': 'Tersimpan'});
    await store.write('draft:other', {'value': 'Tetap ada'});
    await _openForm(tester, store: store);
    await tester.tap(find.byKey(const Key('qc_draft_restore_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('draft_test_input')), 'Diubah');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('qc_draft_discard_button')));
    await tester.pumpAndSettle();

    expect(store.records['draft:test'], isNull);
    expect(store.records['draft:other']?.payload['value'], 'Tetap ada');
    expect(find.byKey(const Key('draft_test_form')), findsNothing);
  });

  testWidgets('matching draft prompts and Continue restores it',
      (tester) async {
    final store = _MemoryDraftStore();
    await store.write('draft:test', {'value': 'Nilai lama'});

    await _openForm(tester, store: store);

    expect(find.text('Draft ditemukan'), findsOneWidget);
    await tester.tap(find.byKey(const Key('qc_draft_restore_button')));
    await tester.pumpAndSettle();
    expect(find.text('Nilai lama'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Simpan sebagai draft?'), findsNothing);
    expect(store.records['draft:test'], isNotNull);
  });

  testWidgets('draft dialogs stay light and fit at 320px under a dark theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemoryDraftStore();
    await store.write('draft:test', {'value': 'Nilai lama'});
    await _openForm(tester, store: store, theme: ThemeData.dark());

    var dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, AppColors.surface);
    expect(dialog.surfaceTintColor, Colors.transparent);
    expect(
      tester.widget<Text>(find.text('Draft ditemukan')).style?.color,
      AppColors.textMain,
    );
    expect(
      tester
          .widget<Text>(find.text(
            'Ada isian yang belum selesai. Lanjutkan dari draft terakhir?',
          ))
          .style
          ?.color,
      AppColors.textMuted,
    );

    await tester.tap(find.byKey(const Key('qc_draft_restart_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('draft_test_input')), 'Ubah');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, AppColors.surface);
    expect(dialog.surfaceTintColor, Colors.transparent);
    expect(
      tester.widget<Text>(find.text('Simpan sebagai draft?')).style?.color,
      AppColors.textMain,
    );
    expect(
      tester
          .widget<Text>(find.text(
            'Data yang sudah diisi dapat disimpan dan dilanjutkan nanti.',
          ))
          .style
          ?.color,
      AppColors.textMuted,
    );

    final cancel = find.byKey(const Key('qc_draft_cancel_button'));
    final discard = find.byKey(const Key('qc_draft_discard_button'));
    final save = find.byKey(const Key('qc_draft_save_button'));
    final cancelButton = tester.widget<FilledButton>(cancel);
    final discardButton = tester.widget<FilledButton>(discard);
    final saveButton = tester.widget<FilledButton>(save);
    expect(
      cancelButton.style?.backgroundColor?.resolve({}),
      AppColors.rejectedText,
    );
    expect(
      discardButton.style?.backgroundColor?.resolve({}),
      AppColors.rejectedText,
    );
    expect(
      saveButton.style?.backgroundColor?.resolve({}),
      AppColors.primary,
    );
    for (final button in [cancelButton, discardButton, saveButton]) {
      expect(
        button.style?.foregroundColor?.resolve({}),
        AppColors.surface,
      );
    }
    expect(tester.getSize(cancel).height, 48);
    expect(tester.getSize(discard), tester.getSize(cancel));
    expect(tester.getSize(save), tester.getSize(cancel));
    expect(tester.getTopLeft(discard).dy - tester.getBottomLeft(cancel).dy, 12);
    expect(tester.getTopLeft(save).dy - tester.getBottomLeft(discard).dy, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start Over deletes the draft and keeps fresh state', (
    tester,
  ) async {
    final store = _MemoryDraftStore();
    await store.write('draft:test', {'value': 'Nilai lama'});

    await _openForm(tester, store: store);
    await tester.tap(find.byKey(const Key('qc_draft_restart_button')));
    await tester.pumpAndSettle();

    expect(find.text('Nilai lama'), findsNothing);
    expect(store.records['draft:test'], isNull);
    expect(find.byKey(const Key('draft_test_form')), findsOneWidget);
  });

  testWidgets('wrong identity is not offered for restoration', (tester) async {
    final store = _MemoryDraftStore();
    await store.write('draft:other', {'value': 'Milik template lain'});

    await _openForm(tester, store: store);

    expect(find.text('Draft ditemukan'), findsNothing);
    expect(find.text('Milik template lain'), findsNothing);
  });

  testWidgets('save failure keeps the form and in-memory value',
      (tester) async {
    final store = _MemoryDraftStore(failWrite: true);
    await _openForm(tester, store: store);
    await tester.enterText(find.byKey(const Key('draft_test_input')), 'Aman');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('qc_draft_save_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft_test_form')), findsOneWidget);
    expect(find.text('Aman'), findsOneWidget);
    expect(find.text('Draft tidak dapat disimpan. Coba lagi.'), findsOneWidget);
  });

  testWidgets('successful completion deletes the draft before exiting', (
    tester,
  ) async {
    final store = _MemoryDraftStore();
    await store.write('draft:test', {'value': 'Tersimpan'});
    await _openForm(tester, store: store);
    await tester.tap(find.byKey(const Key('qc_draft_restore_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('draft_test_complete')));
    await tester.pumpAndSettle();

    expect(store.records['draft:test'], isNull);
    expect(find.byKey(const Key('draft_test_form')), findsNothing);
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  required _MemoryDraftStore store,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('open_draft_test_form'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _DraftHarness(store: store),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open_draft_test_form')));
  await tester.pumpAndSettle();
}

class _DraftHarness extends StatefulWidget {
  final _MemoryDraftStore store;

  const _DraftHarness({required this.store});

  @override
  State<_DraftHarness> createState() => _DraftHarnessState();
}

class _DraftHarnessState extends State<_DraftHarness> {
  final _controller = TextEditingController();
  final _protectionKey = GlobalKey<QCDraftProtectionState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QCDraftProtection(
      key: _protectionKey,
      identity: 'draft:test',
      store: widget.store,
      createSnapshot: () => {'value': _controller.text},
      restoreSnapshot: (draft) async {
        _controller.text = draft['value']?.toString() ?? '';
        setState(() {});
      },
      hasProcessingEvidence: false,
      preserveEvidence: () {},
      releaseEvidence: () {},
      child: Scaffold(
        key: const Key('draft_test_form'),
        appBar: AppBar(title: const Text('Form QC')),
        body: Column(
          children: [
            TextField(
              key: const Key('draft_test_input'),
              controller: _controller,
            ),
            TextButton(
              key: const Key('draft_test_normal_pop'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Normal pop'),
            ),
            TextButton(
              key: const Key('draft_test_complete'),
              onPressed: _protectionKey.currentState?.completeAndPop,
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryDraftStore extends QCLocalDraftStore {
  final Map<String, QCLocalDraftRecord> records = {};
  final bool failWrite;

  _MemoryDraftStore({this.failWrite = false});

  @override
  Future<QCLocalDraftRecord?> read(String identity) async => records[identity];

  @override
  Future<void> write(String identity, Map<String, dynamic> payload) async {
    if (failWrite) throw const QCLocalDraftStorageException();
    records[identity] = QCLocalDraftRecord(
      updatedAt: DateTime(2026, 8, 24),
      payload: Map<String, dynamic>.from(payload),
    );
  }

  @override
  Future<void> delete(String identity) async => records.remove(identity);
}
