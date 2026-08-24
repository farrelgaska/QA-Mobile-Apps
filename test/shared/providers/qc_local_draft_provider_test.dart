import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/checklist_item_model.dart';
import 'package:mobile/shared/models/enums.dart';
import 'package:mobile/shared/models/pekerjaan_model.dart';
import 'package:mobile/shared/models/qc_material_evaluation_model.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';
import 'package:mobile/shared/providers/qc_material_form_provider.dart';
import 'package:mobile/shared/providers/qc_pekerjaan_form_provider.dart';

void main() {
  test('pekerjaan local draft restores values, status, and available evidence',
      () async {
    final directory = await Directory.systemTemp.createTemp('qc-work-draft-');
    final evidence = File('${directory.path}${Platform.pathSeparator}work.jpg');
    await evidence.writeAsBytes([1, 2, 3]);
    final template = _workTemplate();
    final source = QCPekerjaanFormProvider()..init(template);
    final restored = QCPekerjaanFormProvider()..init(template);
    addTearDown(() async {
      restored.preserveLocalDraftEvidence();
      source.dispose();
      restored.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    source.areaController.text = 'Zona A';
    source.locationDetailController.text = 'Tiang 12';
    source.mitraController.text = 'Mitra QC';
    expect(source.goToChecklistStep(), isNull);
    source.updateResult(0, 'Ada retak');
    source.updateStatus(0, QCResultStatus.fail);
    source.updateIssueNote(0, 'Perlu perbaikan');
    final draft = source.createLocalDraftSnapshot();
    final item = (draft['items'] as List).single as Map<String, dynamic>;
    item['localPhotos'] = [
      {
        'path': evidence.path,
        'name': 'work.jpg',
        'mimeType': 'image/jpeg',
      },
      {
        'path': '${directory.path}${Platform.pathSeparator}missing.jpg',
        'name': 'missing.jpg',
        'mimeType': 'image/jpeg',
      },
    ];

    await restored.restoreLocalDraftSnapshot(draft);

    expect(restored.currentStep, 1);
    expect(restored.areaController.text, 'Zona A');
    expect(restored.itemResults.single, 'Ada retak');
    expect(restored.itemStatuses.single, ChecklistStatus.tidakSesuai);
    expect(restored.itemIssues.single, 'Perlu perbaikan');
    expect(restored.pendingItemPhotos.single.single.path, evidence.path);
    expect(restored.pendingItemPhotoBytes.single.single, [1, 2, 3]);
  });

  test('material local draft restores general, validation, and evidence state',
      () async {
    final directory = await Directory.systemTemp.createTemp('qc-mat-draft-');
    final evidence = File('${directory.path}${Platform.pathSeparator}mat.jpg');
    await evidence.writeAsBytes([4, 5, 6]);
    final template = _materialTemplate();
    final source = QCMaterialFormProvider()
      ..init(template.id, template: template);
    final restored = QCMaterialFormProvider()
      ..init(template.id, template: template);
    addTearDown(() async {
      restored.preserveLocalDraftEvidence();
      source.dispose();
      restored.dispose();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    source.poNumberController.text = 'PO-LOCAL-1';
    source.updateAnswer(0, '-2.5');
    source.setParameterEvaluationStatus(
      sampleIndex: 0,
      answerIndex: 0,
      status: QCSampleEvaluationStatus.outOfStandard,
    );
    source.updateIssueNote(0, 'Di bawah standar');
    source.samples.single.notesController.text = 'Periksa ulang';
    final draft = source.createLocalDraftSnapshot();
    final sample = (draft['samples'] as List).single as Map<String, dynamic>;
    final answer = (sample['answers'] as List).single as Map<String, dynamic>;
    answer['localPhotos'] = [
      {
        'path': evidence.path,
        'name': 'mat.jpg',
        'mimeType': 'image/jpeg',
      },
    ];

    await restored.restoreLocalDraftSnapshot(draft);

    expect(restored.poNumberController.text, 'PO-LOCAL-1');
    expect(restored.answers.single.value, '-2.5');
    expect(restored.answers.single.status, QCResultStatus.fail);
    expect(
      restored.answers.single.evaluationStatus,
      QCSampleEvaluationStatus.outOfStandard.apiValue,
    );
    expect(restored.answers.single.issueNote, 'Di bawah standar');
    expect(restored.samples.single.notesController.text, 'Periksa ulang');
    expect(restored.localItemPhotos.single.single.path, evidence.path);
    expect(restored.localItemPhotoBytes.single.single, [4, 5, 6]);
  });

  test('draft identities are separated by form type and template', () {
    final work = QCPekerjaanFormProvider()..init(_workTemplate());
    final otherWork = QCPekerjaanFormProvider()
      ..init(_workTemplate(id: 'WORK-OTHER'));
    final material = QCMaterialFormProvider()
      ..init('MAT-LOCAL', template: _materialTemplate());
    addTearDown(() {
      work.dispose();
      otherWork.dispose();
      material.dispose();
    });

    expect(work.localDraftIdentity, isNot(otherWork.localDraftIdentity));
    expect(work.localDraftIdentity, isNot(material.localDraftIdentity));
  });
}

PekerjaanModel _workTemplate({String id = 'WORK-LOCAL'}) => PekerjaanModel(
      id: id,
      name: 'Draft pekerjaan',
      segment: WorkSegment.construction,
      description: '',
      checklistItems: [
        ChecklistItemModel(
          id: 'work-text',
          title: 'Kondisi pekerjaan',
          inputType: InputType.text,
          standard: 'Baik',
          requiredPhoto: false,
        ),
      ],
      status: 'Aktif',
    );

QCMaterialTemplate _materialTemplate() => QCMaterialTemplate(
      id: 'MAT-LOCAL',
      name: 'Draft material',
      code: 'MAT-LOCAL',
      description: '',
      checklistItems: [
        QCChecklistItem(
          id: 'material-number',
          label: 'Nilai material',
          category: 'Dimensi',
          inputType: QCInputType.number,
          standardText: '0 sampai 10',
          minValue: 0,
          maxValue: 10,
        ),
      ],
    );
