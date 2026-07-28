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

test('empty reports produce six forward-looking zero-value Indonesian week labels', () => {
  const trend = buildRecentWeeklyReportTrend([], referenceDate);

  assert.equal(trend.length, RECENT_REPORT_WEEK_COUNT);
  assert.deepEqual(
    trend.map(point => point.name),
    [
      'Mgu 27/07',
      'Mgu 03/08',
      'Mgu 10/08',
      'Mgu 17/08',
      'Mgu 24/08',
      'Mgu 31/08',
    ]
  );
  assert.equal(new Set(trend.map(point => point.name)).size, trend.length);
  assert.ok(trend.every(point =>
    point.Laporan === 0 && point.Disetujui === 0
  ));
});

test('reports in the current week populate the first bucket', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-07-28T09:00:00+07:00'),
      report('2026-07-30T09:00:00+07:00', 'APPROVED'),
    ],
    referenceDate
  );

  assert.deepEqual(trend[0], {
    name: 'Mgu 27/07',
    Laporan: 2,
    Disetujui: 1,
  });
  assert.ok(trend.slice(1).every(point =>
    point.Laporan === 0 && point.Disetujui === 0
  ));
});

test('future weeks aggregate reports while past, out-of-range, and invalid dates are ignored', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-07-28T10:00:00+07:00', 'APPROVED'),
      report('2026-08-03T10:00:00+07:00'),
      report('2026-08-09T10:00:00+07:00', 'APPROVED'),
      report('2026-08-17T10:00:00+07:00', 'APPROVED'),
      report('2026-08-30T10:00:00+07:00'),
      report('2026-07-20T10:00:00+07:00', 'APPROVED'),
      report('2026-09-07T10:00:00+07:00', 'APPROVED'),
      report('invalid-date', 'APPROVED'),
    ],
    referenceDate
  );

  assert.deepEqual(
    trend.map(({ Laporan, Disetujui }) => [Laporan, Disetujui]),
    [
      [1, 1],
      [2, 1],
      [0, 0],
      [1, 1],
      [1, 0],
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
