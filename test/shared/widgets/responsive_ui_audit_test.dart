import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:mobile/features/qc_material/screens/qc_material_list_screen.dart';
import 'package:mobile/features/qc_pekerjaan/screens/qc_pekerjaan_segment_screen.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/template_choice_option.dart';
import 'package:mobile/shared/widgets/checklist_item_card.dart';

void main() {
  const viewports = <double>[320, 360, 375, 392];

  group('Step 2: Login Responsive Audit across 320, 360, 375, 392 px', () {
    for (final width in viewports) {
      testWidgets('LoginScreen renders cleanly without overflow at $width px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: LoginScreen(key: ValueKey('login-$width')),
          ),
        );
        await tester.pump();

        // 1. Verify header elements
        expect(find.text('QA Mobile Apps'), findsOneWidget);
        expect(find.text('Masuk ke QA Digitalization'), findsOneWidget);

        // 2. Verify inputs are fully visible and editable
        expect(find.text('NIK / Nama Pengguna'), findsOneWidget);
        expect(find.text('Kata Sandi'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, '').first,
          'NIK-908271',
        );
        await tester.pump();

        // 3. Verify actions (remember me, forgot password)
        expect(find.text('Ingat Saya'), findsOneWidget);
        expect(find.text('Lupa Kata Sandi?'), findsOneWidget);

        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

        await tester.tap(find.byKey(const Key('forgot-password-action')));
        await tester.pump();
        expect(find.textContaining('Hubungi dukungan TI'), findsOneWidget);

        // 4. Verify login button remains reachable
        expect(find.text('Masuk'), findsOneWidget);

        // 5. Verify credentials box
        expect(find.textContaining('Kredensial Akun Demo'), findsOneWidget);

        // 6. Ensure no RenderFlex overflow
        expect(tester.takeException(), isNull, reason: 'Viewport $width px');
      });
    }
  });

  group('Step 3: QC Parameter Card Audit across viewports and input types', () {
    const customOptions = [
      TemplateChoiceOption(
        id: 'opt-pass',
        label: 'Sesuai Kriteria',
        value: 'PASS',
        outcome: 'PASS',
        position: 0,
      ),
      TemplateChoiceOption(
        id: 'opt-fail',
        label: 'Tidak Sesuai Kriteria',
        value: 'FAIL',
        outcome: 'FAIL',
        position: 1,
      ),
    ];

    for (final width in viewports) {
      testWidgets('Numeric card with status badge and long title at $width px',
          (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Test WITHIN_STANDARD (Pass)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChecklistItemCard(
                  itemNumber: 1,
                  title:
                      'Pengujian Kuat Tarik dan Pemanjangan Selubung Luar Kabel Fiber Optik Sesuai Standar Industri',
                  standardText: '122.0 - 128.0 mm',
                  inputType: QCInputType.number,
                  unit: 'mm',
                  minValue: 122.0,
                  maxValue: 128.0,
                  currentStatus: QCResultStatus.pass,
                  resultValue: '125.5',
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
          ),
        );
        await tester.pump();

        expect(find.text('Sesuai Standar'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.text('Standar: 122.0 - 128.0 mm'), findsOneWidget);
        expect(find.text('mm'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Numeric pass at $width px');

        // Test OUT_OF_STANDARD (Fail) with issue note
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChecklistItemCard(
                  itemNumber: 1,
                  title:
                      'Pengujian Kuat Tarik dan Pemanjangan Selubung Luar Kabel Fiber Optik Sesuai Standar Industri',
                  standardText: '122.0 - 128.0 mm',
                  inputType: QCInputType.number,
                  unit: 'mm',
                  minValue: 122.0,
                  maxValue: 128.0,
                  currentStatus: QCResultStatus.fail,
                  resultValue: '135.0',
                  issueDescription:
                      'Nilai ketebalan melebihi toleransi maksimal',
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
          ),
        );
        await tester.pump();

        expect(find.text('Tidak Sesuai Standar'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Keterangan Masalah *'), findsOneWidget);
        expect(
          find.text('Nilai ketebalan melebihi toleransi maksimal'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull,
            reason: 'Numeric fail at $width px');
      });

      testWidgets('Choice card with wrapping chips at $width px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String selectedValue = '';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChecklistItemCard(
                  itemNumber: 2,
                  title: 'Kondisi Fisik dan Kelengkapan Marking Kabel',
                  standardText: 'Marking harus terbaca jelas dan rapi',
                  inputType: QCInputType.choice,
                  choiceOptions: customOptions,
                  currentStatus: QCResultStatus.pass,
                  resultValue: 'PASS',
                  issueDescription: '',
                  photos: const [],
                  isLocked: false,
                  onStatusChanged: (_) {},
                  onResultValueChanged: (v) => selectedValue = v,
                  onIssueDescriptionChanged: (_) {},
                  onAddPhoto: () {},
                  onDeletePhoto: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Sesuai Kriteria'), findsOneWidget);
        expect(find.text('Tidak Sesuai Kriteria'), findsOneWidget);
        expect(find.text('Sesuai Standar'), findsOneWidget);

        await tester.tap(find.text('Tidak Sesuai Kriteria'));
        await tester.pump();
        expect(selectedValue, 'FAIL');
        expect(tester.takeException(), isNull,
            reason: 'Choice chips at $width px');
      });

      testWidgets('Boolean check card at $width px', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String selectedValue = '';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChecklistItemCard(
                  itemNumber: 3,
                  title: 'Pemeriksaan Segel Pabrik',
                  standardText: 'Segel pabrik dalam keadaan utuh',
                  inputType: QCInputType.booleanCheck,
                  currentStatus: QCResultStatus.notFilled,
                  resultValue: '',
                  issueDescription: '',
                  photos: const [],
                  isLocked: false,
                  onStatusChanged: (_) {},
                  onResultValueChanged: (v) => selectedValue = v,
                  onIssueDescriptionChanged: (_) {},
                  onAddPhoto: () {},
                  onDeletePhoto: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Sesuai (Ya)'), findsOneWidget);
        expect(find.text('Tidak Sesuai (Tidak)'), findsOneWidget);
        expect(find.text('Belum Diisi'), findsOneWidget);

        await tester.tap(find.text('Sesuai (Ya)'));
        await tester.pump();
        expect(selectedValue, 'Ya');
        expect(tester.takeException(), isNull,
            reason: 'Boolean check at $width px');
      });

      testWidgets('Text / manual status card at $width px', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        QCResultStatus currentStatus = QCResultStatus.notFilled;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SingleChildScrollView(
                  child: ChecklistItemCard(
                    itemNumber: 4,
                    title: 'Pemeriksaan Visual Struktur Kabel',
                    standardText: 'Diperiksa oleh Staff di lapangan',
                    inputType: QCInputType.text,
                    currentStatus: currentStatus,
                    resultValue: 'Hasil inspeksi visual baik',
                    issueDescription: '',
                    photos: const [],
                    isLocked: false,
                    onStatusChanged: (s) => setState(() => currentStatus = s),
                    onResultValueChanged: (_) {},
                    onIssueDescriptionChanged: (_) {},
                    onAddPhoto: () {},
                    onDeletePhoto: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Status Pemeriksaan Staff *'), findsOneWidget);
        expect(find.text('Belum Diisi'), findsOneWidget);

        // Tap Sesuai Standar chip in selector
        await tester.tap(find.text('Sesuai Standar').last);
        await tester.pump();
        expect(currentStatus, QCResultStatus.pass);

        // Re-pump with updated status
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SingleChildScrollView(
                  child: ChecklistItemCard(
                    itemNumber: 4,
                    title: 'Pemeriksaan Visual Struktur Kabel',
                    standardText: 'Diperiksa oleh Staff di lapangan',
                    inputType: QCInputType.text,
                    currentStatus: currentStatus,
                    resultValue: 'Hasil inspeksi visual baik',
                    issueDescription: '',
                    photos: const [],
                    isLocked: false,
                    onStatusChanged: (s) => setState(() => currentStatus = s),
                    onResultValueChanged: (_) {},
                    onIssueDescriptionChanged: (_) {},
                    onAddPhoto: () {},
                    onDeletePhoto: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        // Tap Tidak Sesuai Standar chip
        await tester.tap(find.text('Tidak Sesuai Standar').last);
        await tester.pump();
        expect(currentStatus, QCResultStatus.fail);

        // Re-pump with fail status
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: SingleChildScrollView(
                  child: ChecklistItemCard(
                    itemNumber: 4,
                    title: 'Pemeriksaan Visual Struktur Kabel',
                    standardText: 'Diperiksa oleh Staff di lapangan',
                    inputType: QCInputType.text,
                    currentStatus: currentStatus,
                    resultValue: 'Hasil inspeksi visual baik',
                    issueDescription: '',
                    photos: const [],
                    isLocked: false,
                    onStatusChanged: (s) => setState(() => currentStatus = s),
                    onResultValueChanged: (_) {},
                    onIssueDescriptionChanged: (_) {},
                    onAddPhoto: () {},
                    onDeletePhoto: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Keterangan Masalah *'), findsOneWidget);

        expect(tester.takeException(), isNull,
            reason: 'Manual text status at $width px');
      });
    }
  });

  group('Step 4: Representative QC Screens Responsive Audit', () {
    for (final width in viewports) {
      testWidgets('QCPekerjaanSegmentScreen renders cleanly at $width px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: QCPekerjaanSegmentScreen(),
          ),
        );
        await tester.pump();

        expect(find.text('QC Pekerjaan'), findsOneWidget);
        expect(find.text('Provisioning'), findsOneWidget);
        expect(find.text('Assurance'), findsOneWidget);
        expect(find.text('Construction'), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Pekerjaan segment at $width px');
      });

      testWidgets('QCMaterialListScreen renders header and search at $width px',
          (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: QCMaterialListScreen(),
          ),
        );
        await tester.pump();

        expect(find.text('QC Material'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: 'Material list at $width px');
      });
    }
  });
}
