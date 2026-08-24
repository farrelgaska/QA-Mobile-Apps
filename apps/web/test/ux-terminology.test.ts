import assert from 'node:assert/strict';
import test from 'node:test';

import {
  getReportStatusLabel,
  getStandardResultLabel,
  normalizeReportStatus,
} from '../src/utils/status.ts';

test('public terminology changes do not change stored status values', () => {
  assert.equal(getReportStatusLabel('SUBMITTED'), 'Dikirim');
  assert.equal(normalizeReportStatus('Dikirim'), 'SUBMITTED');
  assert.equal(normalizeReportStatus('Menunggu Review'), 'SUBMITTED');
  assert.equal(getStandardResultLabel('Perlu Review'), 'Perlu Ditinjau');
});
