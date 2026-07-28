import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildRecentWeeklyReportTrend,
  RECENT_REPORT_WEEK_COUNT,
  type ReportTrendInput,
} from '../src/utils/reportTrend.ts';

const referenceDate = new Date(2026, 6, 28, 12);

const report = (
  submittedAt: string,
  status: ReportTrendInput['status'] = 'SUBMITTED'
): ReportTrendInput => ({ submittedAt, status });

test('empty reports produce six unique zero-value Indonesian week labels', () => {
  const trend = buildRecentWeeklyReportTrend([], referenceDate);

  assert.equal(trend.length, RECENT_REPORT_WEEK_COUNT);
  assert.deepEqual(
    trend.map(point => point.name),
    [
      'Mgu 22/06',
      'Mgu 29/06',
      'Mgu 06/07',
      'Mgu 13/07',
      'Mgu 20/07',
      'Mgu 27/07',
    ]
  );
  assert.equal(new Set(trend.map(point => point.name)).size, trend.length);
  assert.ok(trend.every(point =>
    point.Laporan === 0 && point.Disetujui === 0
  ));
});

test('one active week keeps surrounding zero weeks', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-07-28T09:00:00+07:00'),
      report('2026-07-30T09:00:00+07:00', 'APPROVED'),
    ],
    referenceDate
  );

  assert.deepEqual(trend.slice(0, 5).map(point => point.Laporan), [0, 0, 0, 0, 0]);
  assert.deepEqual(trend[5], {
    name: 'Mgu 27/07',
    Laporan: 2,
    Disetujui: 1,
  });
});

test('multiple active weeks aggregate totals and approvals without duplicates', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-06-22T10:00:00+07:00', 'APPROVED'),
      report('2026-07-06T10:00:00+07:00'),
      report('2026-07-12T10:00:00+07:00', 'APPROVED'),
      report('2026-07-20T10:00:00+07:00', 'APPROVED'),
      report('2026-07-26T10:00:00+07:00'),
      report('2026-05-01T10:00:00+07:00', 'APPROVED'),
      report('invalid-date', 'APPROVED'),
    ],
    referenceDate
  );

  assert.deepEqual(
    trend.map(({ Laporan, Disetujui }) => [Laporan, Disetujui]),
    [
      [1, 1],
      [0, 0],
      [2, 1],
      [0, 0],
      [2, 1],
      [0, 0],
    ]
  );
  assert.equal(new Set(trend.map(point => point.name)).size, trend.length);
});

test('chart renders gradient areas and smooth lines for both series', () => {
  const source = fs.readFileSync(new URL(
    '../src/components/dashboard/ReportChart.tsx',
    import.meta.url
  ), 'utf8');

  assert.match(source, /<ComposedChart/);
  assert.match(source, /<linearGradient id="colorLaporan"/);
  assert.match(source, /<linearGradient id="colorDisetujui"/);
  assert.match(source, /<Area[\s\S]*dataKey="Laporan"/);
  assert.match(source, /<Area[\s\S]*dataKey="Disetujui"/);
  assert.match(source, /<Line\s+type="monotone"\s+dataKey="Laporan"/);
  assert.match(source, /<Line\s+type="monotone"\s+dataKey="Disetujui"/);
});
