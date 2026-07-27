import type {
  ChecklistItem,
  ChecklistResult,
  ParameterEvaluationStatus,
  QCReport,
  ReportSample,
} from '../types/report';

export interface InspectionInformationRow {
  field: string;
  label: string;
  value: string;
}

export interface SamplePageState {
  currentSample: ReportSample | undefined;
  currentIndex: number;
  total: number;
  indicator: string;
  previousSampleId: string | null;
  nextSampleId: string | null;
}

export interface ParameterAdminNoteState {
  required: boolean;
  missing: boolean;
  message: string | null;
}

export interface AdminReviewReadiness {
  failedItems: ChecklistItem[];
  failedItemsMissingAdminNote: ChecklistItem[];
  pendingItems: ChecklistItem[];
  canApprove: boolean;
  canRequestRevision: boolean;
}

export const PARAMETER_EVALUATION_LABELS: Record<ParameterEvaluationStatus, string> = {
  WITHIN_STANDARD: 'Sesuai Standar',
  OUT_OF_STANDARD: 'Tidak Sesuai Standar',
  NOT_EVALUATED: 'Belum Dievaluasi',
};

const parsePersistedJson = (value: unknown): unknown => {
  if (typeof value !== 'string') return value;
  try {
    return JSON.parse(value);
  } catch {
    return undefined;
  }
};

export const sortedPersistedSamples = (
  samples: readonly ReportSample[] = []
): ReportSample[] => [...samples].sort(
  (left, right) => left.sample_number - right.sample_number
);

export const persistedSamplePage = (
  samples: readonly ReportSample[] = [],
  selectedSampleId?: string
): SamplePageState => {
  const sorted = sortedPersistedSamples(samples);
  const requestedIndex = selectedSampleId
    ? sorted.findIndex(sample => sample.id === selectedSampleId)
    : 0;
  const currentIndex = requestedIndex >= 0 ? requestedIndex : 0;
  const currentSample = sorted[currentIndex];
  return {
    currentSample,
    currentIndex,
    total: sorted.length,
    indicator: currentSample
      ? `Sampel ${currentIndex + 1} dari ${sorted.length}`
      : 'Sampel 0 dari 0',
    previousSampleId: currentIndex > 0 ? sorted[currentIndex - 1].id : null,
    nextSampleId: currentIndex < sorted.length - 1
      ? sorted[currentIndex + 1].id
      : null,
  };
};

export const persistedSampleEvaluationStatuses = (
  generalInfo: Readonly<Record<string, string>> = {}
): Readonly<Record<string, ParameterEvaluationStatus>> => {
  const parsed = parsePersistedJson(generalInfo.qcSampleEvaluationStatuses);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
  return Object.fromEntries(
    Object.entries(parsed).filter((entry): entry is [string, ParameterEvaluationStatus] =>
      ['WITHIN_STANDARD', 'OUT_OF_STANDARD', 'NOT_EVALUATED'].includes(
        String(entry[1])
      )
    )
  );
};

export const persistedSamplingFailedNumbers = (
  generalInfo: Readonly<Record<string, string>> = {}
): number[] => {
  const parsed = parsePersistedJson(generalInfo.qcSamplingFailedSampleNumbers);
  if (!Array.isArray(parsed)) return [];
  return parsed.filter((value): value is number =>
    typeof value === 'number' && Number.isInteger(value) && value > 0
  );
};

export const hasPersistedOutOfStandard = (report: QCReport): boolean => {
  const sampleStatuses = persistedSampleEvaluationStatuses(report.general_info);
  return Object.values(sampleStatuses).includes('OUT_OF_STANDARD') ||
    (report.samples ?? []).some(sample =>
      sample.checklist_answers.some(answer =>
        answer.evaluation_status === 'OUT_OF_STANDARD'
      )
    );
};

export const hasCurrentSampleOutOfStandard = (
  sample: ReportSample,
  persistedSampleStatus?: ParameterEvaluationStatus
): boolean =>
  persistedSampleStatus === 'OUT_OF_STANDARD' ||
  sample.checklist_answers.some(answer =>
    answer.evaluation_status === 'OUT_OF_STANDARD'
  );

export const isPersistedStopDecision = (report: QCReport): boolean =>
  report.general_info?.qcSamplingDecision === 'STOP';

export const sampleAdminReviewKey = (
  sampleId: string,
  checklistItemId: string
): string => `${sampleId}:${checklistItemId}`;

export const withEvidenceDisplayUrls = (
  report: QCReport,
  displayUrls: Readonly<Record<string, string>>
): QCReport => ({
  ...report,
  evidenceDisplayUrls: {
    ...(report.evidenceDisplayUrls ?? {}),
    ...displayUrls,
  },
});

export const sampleAdminReviewItems = (report: QCReport): ChecklistItem[] => {
  const itemNames = new Map(
    report.checklistItems.map(item => [item.id, item.name])
  );
  return sortedPersistedSamples(report.samples).flatMap(sample =>
    sample.checklist_answers.map(answer => ({
      id: sampleAdminReviewKey(sample.id, answer.checklist_item_id),
      name: `Sampel ${sample.sample_number} · ${
        itemNames.get(answer.checklist_item_id) || answer.checklist_item_id
      }`,
      standardLabel: answer.standard_text,
      actualValue: String(answer.actual_value ?? ''),
      unit: answer.unit,
      result: answer.admin_evaluation ?? 'NEEDS_REVIEW',
      photoUrls: answer.photo_paths,
      adminNote: answer.admin_note ?? '',
    }))
  );
};

export const updateSampleAdminReview = (
  samples: readonly ReportSample[],
  sampleId: string,
  checklistItemId: string,
  result: ChecklistResult,
  adminNote: string
): ReportSample[] => samples.map(sample => {
  if (sample.id !== sampleId) return sample;
  return {
    ...sample,
    checklist_answers: sample.checklist_answers.map(answer =>
      answer.checklist_item_id === checklistItemId
        ? {
            ...answer,
            admin_evaluation: result,
            admin_note: adminNote,
          }
        : answer
    ),
  };
});

export const parameterAdminNoteState = (
  result: ChecklistResult,
  adminNote?: string
): ParameterAdminNoteState => {
  const required = result === 'FAIL';
  const missing = required && !adminNote?.trim();
  return {
    required,
    missing,
    message: missing ? 'Catatan Admin wajib diisi untuk parameter Gagal.' : null,
  };
};

export const adminReviewReadiness = (
  items: readonly ChecklistItem[],
  reportLevelRevisionNote: string
): AdminReviewReadiness => {
  const failedItems = items.filter(item => item.result === 'FAIL');
  const failedItemsMissingAdminNote = failedItems.filter(item =>
    parameterAdminNoteState(item.result, item.adminNote).missing
  );
  const pendingItems = items.filter(item => item.result === 'NEEDS_REVIEW');
  return {
    failedItems,
    failedItemsMissingAdminNote,
    pendingItems,
    canApprove: items.every(item => item.result === 'PASS'),
    canRequestRevision:
      failedItems.length > 0 &&
      failedItemsMissingAdminNote.length === 0 &&
      reportLevelRevisionNote.trim().length > 0,
  };
};

const INSPECTION_GENERAL_INFO_FIELDS = [
  ['poNumber', 'Nomor PO'],
  ['poDate', 'Tanggal PO'],
  ['doNumber', 'Nomor DO'],
  ['vendorName', 'Vendor'],
  ['materialId', 'Material / Item'],
  ['brandName', 'Merek'],
  ['warehouseLocation', 'Gudang'],
  ['arrivalVolume', 'Volume Kedatangan'],
  ['samplingVolume', 'Volume Sampling'],
  ['tkdnNumber', 'Sertifikat TKDN'],
  ['tkdnCertDate', 'Tanggal Sertifikat TKDN'],
  ['tkdnValue', 'Nilai TKDN'],
  ['stelVersion', 'Sertifikat / Versi STEL'],
  ['qaExpiryDate', 'Masa Berlaku QA / STEL'],
] as const;

export const inspectionInformationRows = (
  report: QCReport
): InspectionInformationRow[] => {
  const generalInfo = report.general_info ?? {};
  const rows: InspectionInformationRow[] = INSPECTION_GENERAL_INFO_FIELDS
    .flatMap(([field, label]) => {
      const value = generalInfo[field]?.trim();
      return value ? [{ field, label, value }] : [];
    });

  if (!generalInfo.samplingVolume?.trim() && report.sample_count) {
    rows.push({
      field: 'sample_count',
      label: 'Jumlah Sampel',
      value: String(report.sample_count),
    });
  }

  const locationValue = [
    report.location?.site_name,
    report.location?.area,
    report.location?.detail_location,
  ].map(value => value?.trim()).filter(Boolean).join(' · ');
  if (locationValue) {
    rows.push({
      field: 'location',
      label: 'Lokasi Pekerjaan / Konstruksi',
      value: locationValue,
    });
  }

  return rows;
};
