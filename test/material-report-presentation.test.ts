import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import type { QCReport, ReportSample } from '../src/types/report.ts';
import {
  canonicalizeReviewSamples,
  requestFollowUpApi,
} from '../src/services/reportApi.ts';
import {
  adminReviewReadiness,
  hasPersistedOutOfStandard,
  inspectionInformationRows,
  isAdminDecisionProcessable,
  isPersistedStopDecision,
  PARAMETER_EVALUATION_LABELS,
  parameterAdminNoteState,
  persistedSampleEvaluationStatuses,
  persistedSamplePage,
  persistedSamplingFailedNumbers,
  sampleAdminReviewItems,
  sampleAdminReviewKey,
  sortedPersistedSamples,
  updateSampleAdminReview,
  withEvidenceDisplayUrls,
} from '../src/utils/materialReportPresentation.ts';
import { mapToSharedReport } from '../src/utils/status.ts';

const sample = (
  id: string,
  sampleNumber: number,
  evaluationStatus: 'NOT_EVALUATED' | 'WITHIN_STANDARD' | 'OUT_OF_STANDARD',
  adminEvaluation: 'PASS' | 'FAIL' | 'NEEDS_REVIEW' = 'NEEDS_REVIEW',
  adminNote = ''
): ReportSample => ({
  id,
  sample_number: sampleNumber,
  inspection_status: 'COMPLETED',
  checklist_answers: [{
    checklist_item_id: `parameter-${sampleNumber}`,
    input_type: 'number',
    actual_value: 8.9,
    note: `note-${sampleNumber}`,
    photo_paths: [`reports/QC-MATERIAL-MULTI/checklist/parameter-${sampleNumber}/photo-${sampleNumber}.jpg`],
    standard_text: '10 mm +/- 5%',
    standard_value: 10,
    unit: 'mm',
    upper_tolerance: 5,
    lower_tolerance: -5,
    minimum_value: 9.5,
    maximum_value: 10.5,
    evaluation_status: evaluationStatus,
    admin_evaluation: adminEvaluation,
    admin_note: adminNote,
  }],
  notes: `sample-${sampleNumber}`,
  photo_paths: [],
  created_at: '2026-07-23T03:00:00.000Z',
  updated_at: '2026-07-23T03:30:00.000Z',
});

const materialReport = (overrides: Partial<QCReport> = {}): QCReport => ({
  id: 'QC-MATERIAL-MULTI',
  type: 'material',
  title: 'Persisted multi-sample report',
  status: 'SUBMITTED',
  locationName: 'Warehouse',
  submittedBy: 'Staff Warehouse',
  submittedByNik: 'WH-1',
  submittedAt: '2026-07-23T04:00:00.000Z',
  standardResult: 'Perlu Review',
  checklistItems: [],
  photos: [],
  general_info: {},
  ...overrides,
});

test('maps every persisted multi-sample and review field into the Admin report model', () => {
  const samples = [
    sample('sample-2', 2, 'OUT_OF_STANDARD'),
    sample('sample-1', 1, 'WITHIN_STANDARD'),
  ];
  const mapped = mapToSharedReport({
    id: 'QC-MATERIAL-MULTI',
    type: 'MATERIAL',
    title: 'Persisted multi-sample report',
    status: 'SUBMITTED',
    samples,
    sample_count: 2,
    review_requested: true,
    review_requested_at: '2026-07-23T04:00:00.000Z',
    review_requested_by_role: 'STAFF_WAREHOUSE',
    review_failed_sample_count: 2,
    review_failed_sample_ids: ['sample-1', 'sample-2'],
    review_failed_sample_numbers: [1, 2],
    general_info: {
      qcSamplingDecision: 'STOP',
      qcSamplingStopReason: 'Retak fisik',
    },
  });

  assert.deepEqual(mapped.samples, samples);
  assert.equal(mapped.sample_count, 2);
  assert.equal(mapped.review_requested, true);
  assert.equal(mapped.review_requested_at, '2026-07-23T04:00:00.000Z');
  assert.deepEqual(mapped.review_failed_sample_ids, ['sample-1', 'sample-2']);
  assert.deepEqual(mapped.review_failed_sample_numbers, [1, 2]);
  assert.equal(mapped.general_info?.qcSamplingDecision, 'STOP');
  assert.equal(mapped.general_info?.qcSamplingStopReason, 'Retak fisik');
  assert.equal(mapped.samples?.[0].notes, 'sample-2');
  assert.equal(mapped.samples?.[0].checklist_answers[0].note, 'note-2');
  assert.equal(
    mapped.samples?.[0].checklist_answers[0].evaluation_status,
    'OUT_OF_STANDARD'
  );
  assert.equal(mapped.samples?.[0].inspection_status, 'COMPLETED');
});

test('sorts persisted samples by sample_number without mutating API order', () => {
  const original = [
    sample('sample-3', 3, 'NOT_EVALUATED'),
    sample('sample-1', 1, 'WITHIN_STANDARD'),
    sample('sample-2', 2, 'OUT_OF_STANDARD'),
  ];

  assert.deepEqual(
    sortedPersistedSamples(original).map(entry => entry.sample_number),
    [1, 2, 3]
  );
  assert.deepEqual(original.map(entry => entry.sample_number), [3, 1, 2]);
});

test('shows one sorted sample page with previous/next boundaries and indicator', () => {
  const samples = [
    sample('sample-3', 3, 'NOT_EVALUATED'),
    sample('sample-1', 1, 'WITHIN_STANDARD'),
    sample('sample-2', 2, 'OUT_OF_STANDARD'),
  ];
  const firstPage = persistedSamplePage(samples);
  assert.equal(firstPage.currentSample?.id, 'sample-1');
  assert.equal(firstPage.indicator, 'Sampel 1 dari 3');
  assert.equal(firstPage.previousSampleId, null);
  assert.equal(firstPage.nextSampleId, 'sample-2');

  const secondPage = persistedSamplePage(samples, firstPage.nextSampleId!);
  assert.equal(secondPage.currentSample?.id, 'sample-2');
  assert.equal(secondPage.indicator, 'Sampel 2 dari 3');
  assert.equal(secondPage.previousSampleId, 'sample-1');
  assert.equal(secondPage.nextSampleId, 'sample-3');

  const lastPage = persistedSamplePage(samples, secondPage.nextSampleId!);
  assert.equal(lastPage.currentSample?.id, 'sample-3');
  assert.equal(lastPage.indicator, 'Sampel 3 dari 3');
  assert.equal(lastPage.previousSampleId, 'sample-2');
  assert.equal(lastPage.nextSampleId, null);
});

test('identical checklist IDs use independent sample-scoped Admin review keys', () => {
  const report = materialReport({
    checklistItems: [{
      id: 'parameter-1',
      name: 'Dimensi',
      standardLabel: '10 mm',
      actualValue: '8.9',
      result: 'NEEDS_REVIEW',
      photoUrls: [],
    }],
    samples: [
      sample('sample-1', 1, 'WITHIN_STANDARD'),
      {
        ...sample('sample-2', 2, 'OUT_OF_STANDARD'),
        checklist_answers: [{
          ...sample('sample-2', 2, 'OUT_OF_STANDARD').checklist_answers[0],
          checklist_item_id: 'parameter-1',
        }],
      },
    ],
  });

  assert.deepEqual(
    sampleAdminReviewItems(report).map(item => [item.id, item.result, item.adminNote]),
    [
      [sampleAdminReviewKey('sample-1', 'parameter-1'), 'NEEDS_REVIEW', ''],
      [sampleAdminReviewKey('sample-2', 'parameter-1'), 'NEEDS_REVIEW', ''],
    ]
  );
});

test('editing one sample never mutates another sample or a shared answer reference', () => {
  const original = [
    sample('sample-1', 1, 'WITHIN_STANDARD'),
    {
      ...sample('sample-2', 2, 'OUT_OF_STANDARD'),
      checklist_answers: [{
        ...sample('sample-2', 2, 'OUT_OF_STANDARD').checklist_answers[0],
        checklist_item_id: 'parameter-1',
      }],
    },
  ];
  const sampleTwoReference = original[1];
  const sampleTwoAnswerReference = original[1].checklist_answers[0];

  const afterSampleOne = updateSampleAdminReview(
    original,
    'sample-1',
    'parameter-1',
    'PASS',
    'Sampel satu diterima'
  );

  assert.equal(afterSampleOne[0].checklist_answers[0].admin_evaluation, 'PASS');
  assert.equal(afterSampleOne[0].checklist_answers[0].admin_note, 'Sampel satu diterima');
  assert.equal(afterSampleOne[1], sampleTwoReference);
  assert.equal(afterSampleOne[1].checklist_answers[0], sampleTwoAnswerReference);
  assert.equal(
    afterSampleOne[1].checklist_answers[0].admin_evaluation,
    'NEEDS_REVIEW'
  );
  assert.equal(afterSampleOne[1].checklist_answers[0].admin_note, '');

  const afterSampleTwo = updateSampleAdminReview(
    afterSampleOne,
    'sample-2',
    'parameter-1',
    'FAIL',
    'Sampel dua harus diganti'
  );

  assert.equal(afterSampleTwo[0], afterSampleOne[0]);
  assert.equal(afterSampleTwo[0].checklist_answers[0].admin_evaluation, 'PASS');
  assert.equal(afterSampleTwo[0].checklist_answers[0].admin_note, 'Sampel satu diterima');
  assert.equal(afterSampleTwo[1].checklist_answers[0].admin_evaluation, 'FAIL');
  assert.equal(
    afterSampleTwo[1].checklist_answers[0].admin_note,
    'Sampel dua harus diganti'
  );
});

test('sample navigation restores each sample local Admin decision and note', () => {
  let samples = [
    sample('sample-1', 1, 'WITHIN_STANDARD'),
    {
      ...sample('sample-2', 2, 'OUT_OF_STANDARD'),
      checklist_answers: [{
        ...sample('sample-2', 2, 'OUT_OF_STANDARD').checklist_answers[0],
        checklist_item_id: 'parameter-1',
      }],
    },
  ];
  samples = updateSampleAdminReview(
    samples,
    'sample-1',
    'parameter-1',
    'PASS',
    'Catatan sampel satu'
  );
  samples = updateSampleAdminReview(
    samples,
    'sample-2',
    'parameter-1',
    'FAIL',
    'Catatan sampel dua'
  );

  const sampleOnePage = persistedSamplePage(samples, 'sample-1');
  const sampleTwoPage = persistedSamplePage(samples, 'sample-2');
  const backToSampleOne = persistedSamplePage(
    samples,
    sampleTwoPage.previousSampleId ?? undefined
  );

  assert.equal(
    sampleOnePage.currentSample?.checklist_answers[0].admin_note,
    'Catatan sampel satu'
  );
  assert.equal(
    sampleTwoPage.currentSample?.checklist_answers[0].admin_note,
    'Catatan sampel dua'
  );
  assert.equal(
    backToSampleOne.currentSample?.checklist_answers[0].admin_evaluation,
    'PASS'
  );
});

test('uses the required Indonesian labels for persisted parameter evaluations', () => {
  assert.deepEqual(PARAMETER_EVALUATION_LABELS, {
    WITHIN_STANDARD: 'Sesuai Standar',
    OUT_OF_STANDARD: 'Tidak Sesuai Standar',
    NOT_EVALUATED: 'Belum Dievaluasi',
  });
});

test('persisted conformity remains independent from the Admin decision', () => {
  const mapped = mapToSharedReport({
    id: 'QC-INDEPENDENT',
    type: 'MATERIAL',
    title: 'Independent decisions',
    status: 'SUBMITTED',
    checklist_items: [{
      id: 'parameter-1',
      parameter_name: 'Dimension',
      input_type: 'number',
      standard_text: '10 mm',
      actual_value: '8.9',
      item_photos: [],
      admin_evaluation: 'PASS',
    }],
    samples: [sample('sample-1', 1, 'OUT_OF_STANDARD')],
  });

  assert.equal(
    mapped.samples?.[0].checklist_answers[0].evaluation_status,
    'OUT_OF_STANDARD'
  );
  assert.equal(mapped.checklistItems[0].result, 'PASS');
});

test('failed parameters require a non-whitespace Admin note', () => {
  assert.deepEqual(parameterAdminNoteState('FAIL', ''), {
    required: true,
    missing: true,
    message: 'Catatan Admin wajib diisi untuk parameter Gagal.',
  });
  assert.equal(parameterAdminNoteState('FAIL', '   ').missing, true);
  assert.deepEqual(parameterAdminNoteState('FAIL', 'Kemasan retak'), {
    required: true,
    missing: false,
    message: null,
  });
  assert.equal(parameterAdminNoteState('PASS', '').required, false);
  assert.equal(parameterAdminNoteState('PASS', '').missing, false);
});

test('PASS, FAIL, and NEEDS_REVIEW parameters remain approvable', () => {
  const item = {
    id: 'parameter-1',
    name: 'Dimensi',
    standardLabel: '10 mm',
    actualValue: '8.9',
    result: 'FAIL' as const,
    photoUrls: [],
    adminNote: '',
  };

  const empty = adminReviewReadiness([item], 'Perbaiki pengiriman');
  assert.equal(empty.canRequestRevision, false);
  assert.equal(empty.failedItemsMissingAdminNote.length, 1);
  assert.equal(empty.canApprove, true);

  const whitespace = adminReviewReadiness(
    [{ ...item, adminNote: '   ' }],
    'Perbaiki pengiriman'
  );
  assert.equal(whitespace.canRequestRevision, false);

  const complete = adminReviewReadiness(
    [{ ...item, adminNote: 'Ukur ulang dimensi material.' }],
    'Perbaiki pengiriman'
  );
  assert.equal(complete.canRequestRevision, true);
  assert.equal(complete.canApprove, true);

  const changedToPass = adminReviewReadiness(
    [{ ...item, result: 'PASS', adminNote: '' }],
    'Perbaiki pengiriman'
  );
  assert.equal(changedToPass.failedItemsMissingAdminNote.length, 0);
  assert.equal(changedToPass.canRequestRevision, false);
  assert.equal(changedToPass.canApprove, true);

  const missingReportNote = adminReviewReadiness(
    [{ ...item, adminNote: 'Ukur ulang dimensi material.' }],
    '   '
  );
  assert.equal(missingReportNote.canRequestRevision, false);
  assert.equal(missingReportNote.canApprove, true);

  const pending = adminReviewReadiness(
    [{ ...item, result: 'NEEDS_REVIEW', adminNote: '' }],
    ''
  );
  assert.equal(pending.canApprove, true);
  assert.equal(pending.canRequestRevision, false);
});

test('only SUBMITTED reports are processable for an Admin decision', () => {
  assert.equal(isAdminDecisionProcessable('SUBMITTED'), true);
  assert.equal(isAdminDecisionProcessable('DRAFT'), false);
  assert.equal(isAdminDecisionProcessable('NEEDS_FOLLOW_UP'), false);
  assert.equal(isAdminDecisionProcessable('APPROVED'), false);
});

test('report decision UI treats failed and pending parameters as informational', () => {
  const detailSource = fs.readFileSync(new URL(
    '../src/pages/ReportDetailPage.tsx',
    import.meta.url
  ), 'utf8');
  const approvalSource = fs.readFileSync(new URL(
    '../src/pages/ApprovalPage.tsx',
    import.meta.url
  ), 'utf8');
  const contextSource = fs.readFileSync(new URL(
    '../src/app/ReportsContext.tsx',
    import.meta.url
  ), 'utf8');
  const informationalMessage =
    'Terdapat parameter yang ditandai Gagal. Admin tetap dapat meminta perbaikan atau menyetujui laporan berdasarkan hasil evaluasi.';

  assert.match(detailSource, new RegExp(informationalMessage));
  assert.match(detailSource, /disabled=\{!isEditable \|\| isApproving \|\| isRequestingRevision\}/);
  assert.match(detailSource, /tidak membatasi keputusan akhir Admin/);
  assert.doesNotMatch(detailSource, /ubah ke Lulus atau minta perbaikan/);
  assert.match(
    approvalSource,
    /!isAdminDecisionProcessable\(approveTarget\.status\)/
  );
  assert.match(approvalSource, /tidak membatasi keputusan akhir Admin/);
  assert.doesNotMatch(approvalSource, /Persetujuan Ditolak/);
  const approveContext = contextSource.slice(
    contextSource.indexOf('const approveReport ='),
    contextSource.indexOf('const requestRevision =')
  );
  assert.match(
    approveContext,
    /!isAdminDecisionProcessable\(report\.status\)/
  );
  assert.doesNotMatch(approveContext, /\.result/);
  assert.doesNotMatch(contextSource, /item\.result !== 'PASS'/);
});

test('multi-sample presentation provides separate Staff and editable Admin notes', () => {
  const source = fs.readFileSync(new URL(
    '../src/components/reports/MaterialSampleEvaluation.tsx',
    import.meta.url
  ), 'utf8');

  assert.match(source, />Catatan Staff</);
  assert.match(source, />Catatan Admin</);
  assert.match(source, /answer\.note \|\| '-'/);
  assert.match(source, /sample\.id/);
  assert.match(source, /answer\.checklist_item_id/);
  assert.match(source, /answer\.admin_evaluation/);
  assert.match(source, /answer\.admin_note/);
  assert.match(source, /event\.target\.value/);
  assert.match(source, /adminNoteState\.message/);
});

test('review API serializes each sample decision against the correct answer identity', async () => {
  const originalFetch = globalThis.fetch;
  let payload: Record<string, any> | undefined;
  globalThis.fetch = async (_input, init) => {
    payload = JSON.parse(String(init?.body));
    return new Response(JSON.stringify({
      id: 'QC-MATERIAL-MULTI',
      type: 'MATERIAL',
      title: 'Persisted multi-sample report',
      status: 'NEEDS_FOLLOW_UP',
      checklist_items: payload?.checklist_items,
      samples: payload?.samples,
    }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  try {
    await requestFollowUpApi(
      'QC-MATERIAL-MULTI',
      'Instruksi revisi',
      'Admin',
      [{
        id: 'parameter-1',
        parameter_name: 'Dimensi',
        input_type: 'number',
        standard_text: '10 mm',
        actual_value: '8.9',
        staff_note: 'Catatan inspeksi Staff',
        item_photos: [],
        admin_evaluation: 'FAIL',
        admin_note: 'Ukur ulang dimensi material.',
      }],
      [
        sample(
          'sample-1',
          1,
          'WITHIN_STANDARD',
          'PASS',
          'Sampel satu diterima'
        ),
        {
          ...sample(
            'sample-2',
            2,
            'OUT_OF_STANDARD',
            'FAIL',
            'Sampel dua harus diganti'
          ),
          checklist_answers: [{
            ...sample(
              'sample-2',
              2,
              'OUT_OF_STANDARD',
              'FAIL',
              'Sampel dua harus diganti'
            ).checklist_answers[0],
            checklist_item_id: 'parameter-1',
          }],
        },
      ]
    );
  } finally {
    globalThis.fetch = originalFetch;
  }

  const item = payload?.checklist_items?.[0];
  assert.equal(item.staff_note, 'Catatan inspeksi Staff');
  assert.equal(item.admin_note, 'Ukur ulang dimensi material.');
  assert.equal(item.admin_evaluation, 'FAIL');
  assert.deepEqual(
    payload?.samples?.map((entry: ReportSample) => ({
      sampleId: entry.id,
      checklistItemId: entry.checklist_answers[0].checklist_item_id,
      decision: entry.checklist_answers[0].admin_evaluation,
      note: entry.checklist_answers[0].admin_note,
    })),
    [{
      sampleId: 'sample-1',
      checklistItemId: 'parameter-1',
      decision: 'PASS',
      note: 'Sampel satu diterima',
    }, {
      sampleId: 'sample-2',
      checklistItemId: 'parameter-1',
      decision: 'FAIL',
      note: 'Sampel dua harus diganti',
    }]
  );
});

test('persisted sample Admin values restore independently after reload', () => {
  const mapped = mapToSharedReport({
    id: 'QC-ADMIN-NOTE-RELOAD',
    type: 'MATERIAL',
    title: 'Admin note reload',
    status: 'NEEDS_FOLLOW_UP',
    checklist_items: [{
      id: 'parameter-1',
      parameter_name: 'Dimensi',
      input_type: 'number',
      standard_text: '10 mm',
      actual_value: '8.9',
      staff_note: 'Catatan inspeksi Staff',
      item_photos: [],
      admin_evaluation: 'FAIL',
      admin_note: 'Ukur ulang dimensi material.',
    }],
    samples: [
      sample(
        'sample-1',
        1,
        'WITHIN_STANDARD',
        'PASS',
        'Sampel satu diterima'
      ),
      {
        ...sample(
          'sample-2',
          2,
          'OUT_OF_STANDARD',
          'FAIL',
          'Sampel dua harus diganti'
        ),
        checklist_answers: [{
          ...sample(
            'sample-2',
            2,
            'OUT_OF_STANDARD',
            'FAIL',
            'Sampel dua harus diganti'
          ).checklist_answers[0],
          checklist_item_id: 'parameter-1',
        }],
      },
    ],
  });

  assert.equal(
    mapped.checklist_items?.[0].staff_note,
    'Catatan inspeksi Staff'
  );
  assert.equal(
    mapped.checklist_items?.[0].admin_note,
    'Ukur ulang dimensi material.'
  );
  assert.equal(mapped.checklistItems[0].adminNote, 'Ukur ulang dimensi material.');
  assert.deepEqual(
    mapped.samples?.map(entry => [
      entry.id,
      entry.checklist_answers[0].checklist_item_id,
      entry.checklist_answers[0].admin_evaluation,
      entry.checklist_answers[0].admin_note,
      entry.checklist_answers[0].note,
    ]),
    [[
      'sample-1',
      'parameter-1',
      'PASS',
      'Sampel satu diterima',
      'note-1',
    ], [
      'sample-2',
      'parameter-1',
      'FAIL',
      'Sampel dua harus diganti',
      'note-2',
    ]]
  );
});

test('action eligibility evaluates Admin decisions across every sample', () => {
  const report = materialReport({
    samples: [
      sample('sample-1', 1, 'WITHIN_STANDARD', 'PASS', ''),
      {
        ...sample('sample-2', 2, 'OUT_OF_STANDARD', 'FAIL', ''),
        checklist_answers: [{
          ...sample('sample-2', 2, 'OUT_OF_STANDARD', 'FAIL', '')
            .checklist_answers[0],
          checklist_item_id: 'parameter-1',
        }],
      },
    ],
  });
  const missingNote = adminReviewReadiness(
    sampleAdminReviewItems(report),
    'Perbaiki sampel gagal'
  );
  assert.equal(missingNote.canApprove, true);
  assert.equal(missingNote.canRequestRevision, false);
  assert.equal(missingNote.failedItemsMissingAdminNote.length, 1);

  const withNoteSamples = updateSampleAdminReview(
    report.samples ?? [],
    'sample-2',
    'parameter-1',
    'FAIL',
    'Ganti sampel dua'
  );
  const readyForRevision = adminReviewReadiness(
    sampleAdminReviewItems({ ...report, samples: withNoteSamples }),
    'Perbaiki sampel gagal'
  );
  assert.equal(readyForRevision.canRequestRevision, true);
  assert.equal(readyForRevision.canApprove, true);

  const allPassSamples = updateSampleAdminReview(
    withNoteSamples,
    'sample-2',
    'parameter-1',
    'PASS',
    ''
  );
  const readyForApproval = adminReviewReadiness(
    sampleAdminReviewItems({ ...report, samples: allPassSamples }),
    ''
  );
  assert.equal(readyForApproval.canApprove, true);
  assert.equal(readyForApproval.canRequestRevision, false);
});

test('warning uses only persisted sample and parameter evaluation statuses', () => {
  const report = materialReport({
    samples: [sample('sample-1', 1, 'NOT_EVALUATED')],
    general_info: {
      qcSampleEvaluationStatuses: '{"sample-1":"OUT_OF_STANDARD"}',
    },
  });

  assert.equal(hasPersistedOutOfStandard(report), true);
  assert.deepEqual(persistedSampleEvaluationStatuses(report.general_info), {
    'sample-1': 'OUT_OF_STANDARD',
  });

  const parameterFailure = materialReport({
    samples: [sample('sample-1', 1, 'OUT_OF_STANDARD')],
  });
  assert.equal(hasPersistedOutOfStandard(parameterFailure), true);

  const legacyReport = materialReport({ samples: undefined, general_info: {} });
  assert.equal(hasPersistedOutOfStandard(legacyReport), false);
});

test('inspection information uses existing keys, hides missing values, and has a legacy empty state', () => {
  const rows = inspectionInformationRows(materialReport({
    sample_count: 2,
    general_info: {
      poNumber: 'PO-017',
      poDate: '',
      doNumber: 'DO-009',
      vendorName: 'Vendor A',
      materialId: 'MAT-1',
      brandName: 'Brand A',
      warehouseLocation: 'Gudang Timur',
      arrivalVolume: '100',
      samplingVolume: '2',
      tkdnNumber: 'TKDN-1',
      tkdnCertDate: '2026-01-15',
      tkdnValue: '42.5%',
      stelVersion: 'STEL-2026',
      qaExpiryDate: '2028-12-31',
    },
    location: {
      site_id: 'site-1',
      site_name: 'Site Bekasi',
      area: 'Area A',
      detail_location: 'Bay 2',
    },
  }));

  assert.deepEqual(rows.map(row => row.field), [
    'poNumber',
    'doNumber',
    'vendorName',
    'materialId',
    'brandName',
    'warehouseLocation',
    'arrivalVolume',
    'samplingVolume',
    'tkdnNumber',
    'tkdnCertDate',
    'tkdnValue',
    'stelVersion',
    'qaExpiryDate',
    'location',
  ]);
  assert.equal(rows.some(row => row.field === 'poDate'), false);
  assert.equal(rows.some(row => row.field === 'sample_count'), false);
  assert.deepEqual(inspectionInformationRows(materialReport({
    sample_count: undefined,
    general_info: {},
    location: undefined,
  })), []);
});

test('sample count is shown only when persisted sampling volume is absent', () => {
  assert.deepEqual(
    inspectionInformationRows(materialReport({
      sample_count: 3,
      general_info: {},
      location: undefined,
    })),
    [{ field: 'sample_count', label: 'Jumlah Sampel', value: '3' }]
  );
});

test('STOP presentation reads persisted reason, failed numbers, and review state', () => {
  const report = materialReport({
    review_requested: true,
    general_info: {
      qcSamplingDecision: 'STOP',
      qcSamplingStopReason: 'Retak fisik pada dua sampel',
      qcSamplingFailedSampleNumbers: '[1,2]',
    },
  });

  assert.equal(isPersistedStopDecision(report), true);
  assert.equal(report.general_info?.qcSamplingStopReason, 'Retak fisik pada dua sampel');
  assert.deepEqual(persistedSamplingFailedNumbers(report.general_info), [1, 2]);
  assert.equal(report.review_requested, true);
});

test('parameter photos remain attached to the correct selected sample', () => {
  const samples = [
    sample('sample-2', 2, 'OUT_OF_STANDARD'),
    sample('sample-1', 1, 'WITHIN_STANDARD'),
  ];
  const firstPage = persistedSamplePage(samples);
  const secondPage = persistedSamplePage(samples, 'sample-2');

  assert.deepEqual(firstPage.currentSample?.checklist_answers[0].photo_paths, [
    'reports/QC-MATERIAL-MULTI/checklist/parameter-1/photo-1.jpg',
  ]);
  assert.deepEqual(secondPage.currentSample?.checklist_answers[0].photo_paths, [
    'reports/QC-MATERIAL-MULTI/checklist/parameter-2/photo-2.jpg',
  ]);
});

test('legacy Material and QC Pekerjaan reports remain compatible', () => {
  const legacyMaterial = mapToSharedReport({
    id: 'QC-LEGACY',
    type: 'MATERIAL',
    title: 'Legacy Material',
    status: 'SUBMITTED',
    checklist_items: [],
  });
  const pekerjaan = mapToSharedReport({
    id: 'QC-WORK',
    type: 'WORK',
    title: 'QC Pekerjaan',
    status: 'SUBMITTED',
    checklist_items: [],
  });

  assert.deepEqual(legacyMaterial.samples, []);
  assert.equal(legacyMaterial.sample_count, 1);
  assert.equal(legacyMaterial.review_requested, false);
  assert.equal(pekerjaan.type, 'pekerjaan');
  assert.deepEqual(pekerjaan.samples, []);
});

test('signed display URLs are attached without mutating canonical sample photos', () => {
  const canonicalPath =
    'reports/QC-MATERIAL-MULTI/checklist/parameter-1/photo-1.jpg';
  const signedUrl =
    'https://project.supabase.co/storage/v1/object/sign/qc-evidence/photo-1.jpg?token=signed';
  const report = materialReport({
    samples: [sample('sample-1', 1, 'OUT_OF_STANDARD')],
  });
  const originalSamples = structuredClone(report.samples);

  const rendered = withEvidenceDisplayUrls(report, {
    [canonicalPath]: signedUrl,
  });

  assert.deepEqual(report.samples, originalSamples);
  assert.deepEqual(rendered.samples, originalSamples);
  assert.equal(rendered.evidenceDisplayUrls?.[canonicalPath], signedUrl);
});

test('review sample serialization restores canonical paths across samples', () => {
  const paths = {
    oneA: 'reports/QC-MATERIAL-MULTI/checklist/parameter-1/one-a.jpg',
    oneB: 'reports/QC-MATERIAL-MULTI/checklist/parameter-1/one-b.jpg',
    twoA: 'reports/QC-MATERIAL-MULTI/checklist/parameter-1/two-a.jpg',
  };
  const displays = Object.fromEntries(
    Object.values(paths).map(path => [
      path,
      `https://project.supabase.co/storage/v1/object/sign/qc-evidence/${path}?token=signed`,
    ])
  );
  const first = sample(
    'sample-1',
    1,
    'OUT_OF_STANDARD',
    'FAIL',
    'Admin sample one'
  );
  const second = {
    ...sample(
      'sample-2',
      2,
      'WITHIN_STANDARD',
      'PASS',
      'Admin sample two'
    ),
    checklist_answers: [{
      ...sample('sample-2', 2, 'WITHIN_STANDARD').checklist_answers[0],
      checklist_item_id: 'parameter-1',
      note: 'Staff sample two',
    }],
  };
  const contaminated = [
    {
      ...first,
      checklist_answers: [{
        ...first.checklist_answers[0],
        note: 'Staff sample one',
        photo_paths: [displays[paths.oneA], displays[paths.oneB]],
      }],
    },
    {
      ...second,
      checklist_answers: [{
        ...second.checklist_answers[0],
        photo_paths: [displays[paths.twoA]],
      }],
    },
  ];

  const serialized = canonicalizeReviewSamples(contaminated, displays);

  assert.deepEqual(serialized.map(entry =>
    entry.checklist_answers[0].photo_paths
  ), [[paths.oneA, paths.oneB], [paths.twoA]]);
  assert.deepEqual(serialized.map(entry =>
    entry.checklist_answers[0].note
  ), ['Staff sample one', 'Staff sample two']);
  assert.deepEqual(serialized.map(entry =>
    entry.checklist_answers[0].evaluation_status
  ), ['OUT_OF_STANDARD', 'WITHIN_STANDARD']);
  assert.ok(
    serialized.flatMap(entry =>
      entry.checklist_answers.flatMap(answer => answer.photo_paths)
    ).every(path => !/^(?:https?:|blob:|data:)/i.test(path))
  );
  assert.match(
    contaminated[0].checklist_answers[0].photo_paths[0],
    /^https:/
  );
});

test('review PATCH never serializes signed display URLs', async () => {
  const originalFetch = globalThis.fetch;
  const canonicalPath =
    'reports/QC-MATERIAL-MULTI/checklist/parameter-1/photo-1.jpg';
  const signedUrl =
    'https://project.supabase.co/storage/v1/object/sign/qc-evidence/photo-1.jpg?token=signed';
  let payload: Record<string, any> | undefined;
  globalThis.fetch = async (_input, init) => {
    payload = JSON.parse(String(init?.body));
    return new Response(JSON.stringify({
      id: 'QC-MATERIAL-MULTI',
      type: 'MATERIAL',
      title: 'Persisted multi-sample report',
      status: 'NEEDS_FOLLOW_UP',
      admin_review: payload?.admin_review,
      samples: payload?.samples,
    }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  };

  try {
    const signedSample = sample(
      'sample-1',
      1,
      'OUT_OF_STANDARD',
      'FAIL',
      'Ukur ulang'
    );
    signedSample.checklist_answers[0].photo_paths = [signedUrl];
    const response = await requestFollowUpApi(
      'QC-MATERIAL-MULTI',
      'Instruksi revisi',
      'Admin',
      [],
      [signedSample],
      { [canonicalPath]: signedUrl }
    );

    assert.equal(response.status, 'NEEDS_FOLLOW_UP');
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.equal(payload?.status, 'NEEDS_FOLLOW_UP');
  assert.equal(payload?.admin_review?.conclusion, 'NOT_PASSED');
  assert.deepEqual(
    payload?.samples?.[0].checklist_answers[0].photo_paths,
    [canonicalPath]
  );
  assert.doesNotMatch(JSON.stringify(payload), /storage\/v1\/object\/sign/);
});

test('failed review PATCH cannot leave an optimistic revision status', () => {
  const source = fs.readFileSync(new URL(
    '../src/app/ReportsContext.tsx',
    import.meta.url
  ), 'utf8');
  const requestRevisionSource = source.slice(
    source.indexOf('const requestRevision ='),
    source.indexOf('const updateChecklistItem =')
  );

  assert.doesNotMatch(
    requestRevisionSource,
    /status:\s*'NEEDS_FOLLOW_UP'/
  );
  assert.match(
    requestRevisionSource,
    /await requestFollowUpApi[\s\S]*applyLocalUpdate/
  );
  assert.match(
    requestRevisionSource,
    /catch \(err\)[\s\S]*throw err/
  );
});

test('sample image rendering resolves display URLs without replacing object paths', () => {
  const source = fs.readFileSync(new URL(
    '../src/components/reports/MaterialSampleEvaluation.tsx',
    import.meta.url
  ), 'utf8');

  assert.match(source, /report\.evidenceDisplayUrls\?\.\[objectPath\]/);
  assert.match(source, /src=\{displayUrl\}/);
  assert.doesNotMatch(source, /answer\.photo_paths\s*=/);
});
