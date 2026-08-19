import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import type { QCReport } from '../src/types/report.ts';
import { workQcDataRows } from '../src/utils/workReportPresentation.ts';

const workReport = (
  overrides: Pick<QCReport, 'location' | 'general_info'>
): Pick<QCReport, 'location' | 'general_info'> => overrides;

test('WORK report data card presents all Data Pekerjaan values', () => {
  const rows = workQcDataRows(workReport({
    location: {
      site_id: 'site-1',
      site_name: 'Site Cikarang',
      area: 'Zona Transmisi A',
      detail_location: '-6.307, 107.172',
    },
    general_info: {
      mitraName: 'PT Mitra Konstruksi',
      qcPekerjaanCurrentStep: 3,
      qcEvidenceCaptureMetadata: {},
    },
  }));

  assert.deepEqual(rows, [
    { label: 'Lokasi Site (Aktif)', value: 'Site Cikarang' },
    { label: 'Area / Zona Kerja', value: 'Zona Transmisi A' },
    { label: 'Detail Lokasi / Koordinat', value: '-6.307, 107.172' },
    { label: 'Nama Mitra Pelaksana', value: 'PT Mitra Konstruksi' },
  ]);
  assert.doesNotMatch(
    JSON.stringify(rows),
    /qcPekerjaanCurrentStep|qcEvidenceCaptureMetadata/
  );
});

test('WORK report data card uses a dash for missing or blank values', () => {
  const rows = workQcDataRows(workReport({
    location: {
      site_id: 'site-1',
      site_name: '',
      area: '   ',
      detail_location: undefined as unknown as string,
    },
    general_info: {
      mitraName: null,
    },
  }));

  assert.deepEqual(rows.map(row => row.value), ['-', '-', '-', '-']);
});

test('report detail swaps only the WORK gallery while preserving QC Material', () => {
  const source = fs.readFileSync(new URL(
    '../src/pages/ReportDetailPage.tsx',
    import.meta.url
  ), 'utf8');

  assert.match(source, /report\.type === 'material'/);
  assert.match(source, /<InspectionInformation report=\{report\} \/>/);
  assert.match(source, /<Card title="Data QC Pekerjaan">/);
  assert.match(source, /workQcDataRows\(report\)/);
  assert.doesNotMatch(
    source,
    /Galeri Foto Lapangan|Tidak ada foto bukti lapangan/
  );
});
