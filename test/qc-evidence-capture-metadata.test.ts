import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import type { ReportGeneralInfo } from '../src/types/report.ts';
import { mapToSharedReport } from '../src/utils/status.ts';
import {
  evidenceCapturePresentation,
} from '../src/utils/materialReportPresentation.ts';

const PHOTO_PATH =
  'reports/QC-EVIDENCE-1/checklist/dimension/123e4567-e89b-42d3-a456-426614174000.jpg';

const generalInfo = (
  entry: Record<string, unknown>
): ReportGeneralInfo => ({
  qcEvidenceCaptureMetadata: {
    [PHOTO_PATH]: entry,
  } as unknown as NonNullable<
    ReportGeneralInfo['qcEvidenceCaptureMetadata']
  >,
});

test('complete evidence metadata is prepared for compact Indonesian rendering', () => {
  const capturedAt = '2026-07-29T10:30:00.000+07:00';
  const serverReceivedAt = '2026-07-29T04:00:00.000Z';
  const expectedDate = (value: string) => new Intl.DateTimeFormat('id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));

  const presentation = evidenceCapturePresentation(generalInfo({
    capturedAt,
    latitude: -6.2088,
    longitude: 106.8456,
    accuracyMeters: 3.25,
    locationLabel: '  Gudang Utama  ',
    serverReceivedAt,
  }), PHOTO_PATH);

  assert.deepEqual(presentation, {
    hasMetadata: true,
    capturedAt: expectedDate(capturedAt),
    locationLabel: 'Gudang Utama',
    coordinates: '-6.208800, 106.845600',
    accuracy: '3,25 m',
    serverReceivedAt: expectedDate(serverReceivedAt),
    mapUrl: 'https://www.google.com/maps?q=-6.2088%2C106.8456',
    locationUnavailable: false,
  });
});

test('capture time remains visible when location evidence is unavailable', () => {
  const presentation = evidenceCapturePresentation(generalInfo({
    capturedAt: '2026-07-29T10:30:00.000+07:00',
    latitude: null,
    longitude: null,
    accuracyMeters: null,
    locationLabel: null,
    serverReceivedAt: null,
  }), PHOTO_PATH);

  assert.equal(presentation.hasMetadata, true);
  assert.ok(presentation.capturedAt);
  assert.equal(presentation.locationUnavailable, true);
  assert.equal(presentation.coordinates, null);
  assert.equal(presentation.mapUrl, null);
});

test('missing metadata produces the explicit legacy fallback presentation', () => {
  const presentation = evidenceCapturePresentation({}, PHOTO_PATH);
  const source = fs.readFileSync(new URL(
    '../src/components/reports/MaterialSampleEvaluation.tsx',
    import.meta.url
  ), 'utf8');

  assert.equal(presentation.hasMetadata, false);
  assert.match(source, /Informasi waktu dan lokasi tidak tersedia\./);
  assert.match(source, /Lokasi tidak tersedia\./);
});

test('valid coordinate pairs produce a safely opened Google Maps link', () => {
  const presentation = evidenceCapturePresentation(generalInfo({
    latitude: -6.2088,
    longitude: 106.8456,
  }), PHOTO_PATH);
  const source = fs.readFileSync(new URL(
    '../src/components/reports/MaterialSampleEvaluation.tsx',
    import.meta.url
  ), 'utf8');

  assert.equal(
    presentation.mapUrl,
    'https://www.google.com/maps?q=-6.2088%2C106.8456'
  );
  assert.match(source, /target="_blank"/);
  assert.match(source, /rel="noopener noreferrer"/);
  assert.match(source, /Buka di Google Maps/);
});

test('invalid or incomplete coordinates never produce a map link', () => {
  for (const entry of [
    { latitude: 91, longitude: 106.8456 },
    { latitude: -6.2088, longitude: -181 },
    { latitude: -6.2088, longitude: null },
    { latitude: 'not-a-number', longitude: 106.8456 },
  ]) {
    const presentation = evidenceCapturePresentation(
      generalInfo(entry),
      PHOTO_PATH
    );
    assert.equal(presentation.coordinates, null);
    assert.equal(presentation.mapUrl, null);
  }
});

test('legacy photo string arrays remain canonical and render through the same path', () => {
  const report = mapToSharedReport({
    id: 'QC-EVIDENCE-LEGACY',
    type: 'MATERIAL',
    title: 'Legacy evidence',
    status: 'SUBMITTED',
    general_info: {},
    checklist_items: [],
    samples: [{
      id: 'sample-1',
      sample_number: 1,
      inspection_status: 'COMPLETED',
      notes: '',
      photo_paths: [PHOTO_PATH],
      created_at: '2026-07-29T03:00:00.000Z',
      updated_at: '2026-07-29T03:00:00.000Z',
      checklist_answers: [{
        checklist_item_id: 'dimension',
        input_type: 'number',
        actual_value: 10,
        note: '',
        photo_paths: [PHOTO_PATH],
        standard_text: '10 mm',
        standard_value: 10,
        unit: 'mm',
        upper_tolerance: null,
        lower_tolerance: null,
        minimum_value: null,
        maximum_value: null,
        evaluation_status: 'WITHIN_STANDARD',
      }],
    }],
  });
  const source = fs.readFileSync(new URL(
    '../src/components/reports/MaterialSampleEvaluation.tsx',
    import.meta.url
  ), 'utf8');

  assert.deepEqual(report.samples?.[0].photo_paths, [PHOTO_PATH]);
  assert.deepEqual(
    report.samples?.[0].checklist_answers[0].photo_paths,
    [PHOTO_PATH]
  );
  assert.match(source, /sample\.photo_paths\.map/);
  assert.match(source, /answer\.photo_paths\.map/);
  assert.match(source, /report\.evidenceDisplayUrls\?\.\[objectPath\]/);
});
