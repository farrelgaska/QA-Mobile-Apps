import type {
  ChecklistItem,
  ChecklistResult,
  ParameterEvaluationStatus,
  QCReport,
  ReportGeneralInfo,
  ReportStatus,
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

export type AdminDecisionAction = 'approve' | 'requestRevision';

export const ADMIN_DECISIONS_REQUIRED_MESSAGE =
  'Lengkapi seluruh Keputusan Admin pada setiap parameter di semua sampel dengan status Lulus atau Gagal sebelum melanjutkan.';

export interface EvidenceCapturePresentation {
  hasMetadata: boolean;
  capturedAt: string | null;
  locationLabel: string | null;
  coordinates: string | null;
  accuracy: string | null;
  serverReceivedAt: string | null;
  mapUrl: string | null;
  locationUnavailable: boolean;
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
  generalInfo: Readonly<ReportGeneralInfo> = {}
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
  generalInfo: Readonly<ReportGeneralInfo> = {}
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

const isRecord = (value: unknown): value is Readonly<Record<string, unknown>> =>
  value !== null && typeof value === 'object' && !Array.isArray(value);

const validDate = (value: unknown): Date | null => {
  if (typeof value !== 'string' ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) {
    return null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

const formatLocalDateTime = (value: unknown): string | null => {
  const date = validDate(value);
  return date
    ? new Intl.DateTimeFormat('id-ID', {
        dateStyle: 'medium',
        timeStyle: 'short',
      }).format(date)
    : null;
};

const boundedNumber = (
  value: unknown,
  minimum: number,
  maximum: number
): number | null =>
  typeof value === 'number' &&
  Number.isFinite(value) &&
  value >= minimum &&
  value <= maximum
    ? value
    : null;

export const evidenceCapturePresentation = (
  generalInfo: Readonly<ReportGeneralInfo> | undefined,
  objectPath: string
): EvidenceCapturePresentation => {
  const container = generalInfo?.qcEvidenceCaptureMetadata;
  const entry = isRecord(container) && isRecord(container[objectPath])
    ? container[objectPath]
    : null;
  if (!entry) {
    return {
      hasMetadata: false,
      capturedAt: null,
      locationLabel: null,
      coordinates: null,
      accuracy: null,
      serverReceivedAt: null,
      mapUrl: null,
      locationUnavailable: false,
    };
  }

  const capturedAt = formatLocalDateTime(entry.capturedAt);
  const serverReceivedAt = formatLocalDateTime(entry.serverReceivedAt);
  const latitude = boundedNumber(entry.latitude, -90, 90);
  const longitude = boundedNumber(entry.longitude, -180, 180);
  const hasCoordinatePair = latitude !== null && longitude !== null;
  const locationLabel = typeof entry.locationLabel === 'string' &&
    entry.locationLabel.trim()
    ? entry.locationLabel.trim()
    : null;
  const accuracyMeters = typeof entry.accuracyMeters === 'number' &&
    Number.isFinite(entry.accuracyMeters) &&
    entry.accuracyMeters >= 0
    ? entry.accuracyMeters
    : null;
  const coordinates = hasCoordinatePair
    ? `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`
    : null;
  const accuracy = accuracyMeters === null
    ? null
    : `${new Intl.NumberFormat('id-ID', {
        maximumFractionDigits: 2,
      }).format(accuracyMeters)} m`;
  const mapUrl = hasCoordinatePair
    ? `https://www.google.com/maps?q=${encodeURIComponent(
        `${latitude},${longitude}`
      )}`
    : null;
  const hasMetadata = Boolean(
    capturedAt ||
    serverReceivedAt ||
    locationLabel ||
    coordinates ||
    accuracy
  );

  return {
    hasMetadata,
    capturedAt,
    locationLabel,
    coordinates,
    accuracy,
    serverReceivedAt,
    mapUrl,
    locationUnavailable: Boolean(
      capturedAt && !locationLabel && !hasCoordinatePair
    ),
  };
};

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
      staffEvaluation: answer.evaluation_status ?? 'NOT_EVALUATED',
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
  const pendingItems = items.filter(
    item => item.result !== 'PASS' && item.result !== 'FAIL'
  );
  return {
    failedItems,
    failedItemsMissingAdminNote,
    pendingItems,
    canApprove:
      pendingItems.length === 0 &&
      failedItemsMissingAdminNote.length === 0,
    canRequestRevision:
      pendingItems.length === 0 &&
      failedItems.length > 0 &&
      failedItemsMissingAdminNote.length === 0 &&
      reportLevelRevisionNote.trim().length > 0,
  };
};

export const adminDecisionValidationError = (
  items: readonly ChecklistItem[],
  action: AdminDecisionAction,
  reportLevelRevisionNote = ''
): string | null => {
  const readiness = adminReviewReadiness(items, reportLevelRevisionNote);

  if (readiness.pendingItems.length > 0) {
    return ADMIN_DECISIONS_REQUIRED_MESSAGE;
  }
  if (readiness.failedItemsMissingAdminNote.length > 0) {
    const names = readiness.failedItemsMissingAdminNote
      .map(item => item.name)
      .join(', ');
    return `Setiap parameter Gagal harus memiliki Catatan Admin (${names}).`;
  }
  if (action === 'requestRevision' && readiness.failedItems.length === 0) {
    return 'Tindak lanjut diblokir: harus ada minimal satu parameter yang ditandai Gagal.';
  }
  if (action === 'requestRevision' && !reportLevelRevisionNote.trim()) {
    return 'Catatan instruksi tindak lanjut wajib diisi.';
  }
  return null;
};

export const executeValidatedAdminDecision = async <T>(
  items: readonly ChecklistItem[],
  action: AdminDecisionAction,
  reportLevelRevisionNote: string,
  mutation: () => Promise<T>
): Promise<T> => {
  const validationError = adminDecisionValidationError(
    items,
    action,
    reportLevelRevisionNote
  );
  if (validationError) throw new Error(validationError);
  return mutation();
};

export const isAdminDecisionProcessable = (
  status: ReportStatus
): boolean => status === 'SUBMITTED';

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
