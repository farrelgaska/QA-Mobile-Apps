const { z } = require('zod');
const {
  CANONICAL_QC_EVIDENCE_PATH_PATTERN
} = require('./report.contract');

const QC_EVIDENCE_CAPTURE_METADATA_FIELD = 'qcEvidenceCaptureMetadata';
const MAX_LOCATION_LABEL_LENGTH = 256;
const isoTimestampSchema = z.string().datetime({ offset: true });

const isRecord = value => value !== null &&
  typeof value === 'object' &&
  !Array.isArray(value);

const validTimestampOrNull = value => {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return isoTimestampSchema.safeParse(trimmed).success ? trimmed : null;
};

const boundedNumberOrNull = (value, minimum, maximum) =>
  typeof value === 'number' &&
  Number.isFinite(value) &&
  value >= minimum &&
  value <= maximum
    ? value
    : null;

const accuracyOrNull = value =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0
    ? value
    : null;

const locationLabelOrNull = value => {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 && trimmed.length <= MAX_LOCATION_LABEL_LENGTH
    ? trimmed
    : null;
};

const metadataContainerOrEmpty = generalInfo => {
  if (!isRecord(generalInfo)) return {};
  const value = generalInfo[QC_EVIDENCE_CAPTURE_METADATA_FIELD];
  return isRecord(value) ? value : {};
};

const normalizeEntry = (entry, existingEntry, serverReceivedAt) => {
  if (!isRecord(entry)) return null;
  const existingServerReceivedAt = isRecord(existingEntry)
    ? validTimestampOrNull(existingEntry.serverReceivedAt)
    : null;
  return {
    capturedAt: validTimestampOrNull(entry.capturedAt),
    latitude: boundedNumberOrNull(entry.latitude, -90, 90),
    longitude: boundedNumberOrNull(entry.longitude, -180, 180),
    accuracyMeters: accuracyOrNull(entry.accuracyMeters),
    locationLabel: locationLabelOrNull(entry.locationLabel),
    serverReceivedAt: existingServerReceivedAt || serverReceivedAt
  };
};

const normalizeQCEvidenceCaptureMetadata = (
  report,
  { existingReport = null, now = () => new Date() } = {}
) => {
  const type = report?.type ?? existingReport?.type ?? 'MATERIAL';
  if (type !== 'MATERIAL') return report;

  const generalInfo = report?.general_info ?? report?.generalInfo;
  if (!isRecord(generalInfo) ||
      !Object.prototype.hasOwnProperty.call(
        generalInfo,
        QC_EVIDENCE_CAPTURE_METADATA_FIELD
      )) {
    return report;
  }

  const inputMetadata = metadataContainerOrEmpty(generalInfo);
  const existingGeneralInfo =
    existingReport?.general_info ?? existingReport?.generalInfo;
  const existingMetadata = metadataContainerOrEmpty(existingGeneralInfo);
  const receivedAtValue = now();
  const serverReceivedAt = receivedAtValue instanceof Date
    ? receivedAtValue.toISOString()
    : new Date(receivedAtValue).toISOString();
  const normalizedMetadata = {};

  for (const [rawPath, entry] of Object.entries(inputMetadata)) {
    if (rawPath.length === 0 ||
        !CANONICAL_QC_EVIDENCE_PATH_PATTERN.test(rawPath)) {
      continue;
    }
    const normalizedEntry = normalizeEntry(
      entry,
      existingMetadata[rawPath],
      serverReceivedAt
    );
    if (normalizedEntry) normalizedMetadata[rawPath] = normalizedEntry;
  }

  return {
    ...report,
    general_info: {
      ...generalInfo,
      [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: normalizedMetadata
    }
  };
};

module.exports = {
  QC_EVIDENCE_CAPTURE_METADATA_FIELD,
  MAX_LOCATION_LABEL_LENGTH,
  normalizeQCEvidenceCaptureMetadata
};
