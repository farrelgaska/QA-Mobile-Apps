import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

import {
  buildRecentWeeklyReportTrend,
  type ReportTrendInput,
} from '../src/utils/reportTrend.ts';

const referenceDate = new Date('2026-08-03T12:00:00+07:00');

const report = (
  submittedAt: string,
  status: ReportTrendInput['status'] = 'SUBMITTED',
  reviewedAt?: string
): ReportTrendInput => ({
  submittedAt,
  status,
  ...(reviewedAt === undefined
    ? {}
    : { admin_review: { reviewed_at: reviewedAt } }),
});

test('range starts on 20 July 2026 and includes every week through the current week', () => {
  const trend = buildRecentWeeklyReportTrend([], referenceDate);

  assert.deepEqual(
    trend.map(point => point.name),
    [
      'Mgu 20/07',
      'Mgu 27/07',
      'Mgu 03/08',
    ]
  );
  assert.equal(new Set(trend.map(point => point.name)).size, trend.length);
  assert.ok(trend.every(point =>
    point.Laporan === 0 && point.Disetujui === 0
  ));
});

test('advancing the current date appends one week without generating future weeks', () => {
  const august3 = buildRecentWeeklyReportTrend([], referenceDate);
  const august10 = buildRecentWeeklyReportTrend(
    [],
    new Date('2026-08-10T12:00:00+07:00')
  );

  assert.deepEqual(august10.slice(0, -1), august3);
  assert.deepEqual(august10.at(-1), {
    name: 'Mgu 10/08',
    Laporan: 0,
    Disetujui: 0,
  });
});

test('reports use Monday-to-Sunday Jakarta buckets and empty weeks remain zero', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-07-20T00:00:00+07:00'),
      report('2026-07-26T23:59:59+07:00'),
      report('2026-08-02T23:59:59+07:00'),
      report('2026-08-03T00:00:00+07:00'),
      report('2026-08-02T17:00:00Z'),
    ],
    referenceDate
  );

  assert.deepEqual(
    trend.map(({ Laporan, Disetujui }) => [Laporan, Disetujui]),
    [
      [2, 0],
      [1, 0],
      [2, 0],
    ]
  );
});

test('pre-start, invalid, and future reports neither count nor alter the range', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-07-19T23:59:59+07:00', 'APPROVED'),
      report('invalid-date', 'APPROVED'),
      report('2026-08-10T13:00:00+07:00'),
      report('2026-08-17T00:00:00+07:00'),
    ],
    new Date('2026-08-10T12:00:00+07:00')
  );

  assert.deepEqual(
    trend.map(point => point.name),
    [
      'Mgu 20/07',
      'Mgu 27/07',
      'Mgu 03/08',
      'Mgu 10/08',
    ]
  );
  assert.ok(trend.every(point =>
    point.Laporan === 0 && point.Disetujui === 0
  ));
});

test('approvals use reviewed_at with the documented legacy fallback', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-07-20T10:00:00+07:00', 'APPROVED', '2026-07-30T11:00:00+07:00'),
      report('2026-07-21T10:00:00+07:00', 'APPROVED'),
      report('2026-07-22T10:00:00+07:00', 'APPROVED', 'invalid-date'),
      report('2026-07-23T10:00:00+07:00', 'SUBMITTED', '2026-07-30T10:00:00+07:00'),
      report('2026-07-19T10:00:00+07:00', 'APPROVED', '2026-07-30T10:00:00+07:00'),
      report('2026-07-24T10:00:00+07:00', 'APPROVED', '2026-08-04T10:00:00+07:00'),
    ],
    referenceDate
  );

  assert.deepEqual(
    trend.map(({ Laporan, Disetujui }) => [Laporan, Disetujui]),
    [
      [5, 2],
      [0, 1],
      [0, 0],
    ]
  );
});

test('range and bucketing remain stable across month and year boundaries', () => {
  const trend = buildRecentWeeklyReportTrend(
    [
      report('2026-12-27T23:59:59+07:00'),
      report('2026-12-28T00:00:00+07:00', 'APPROVED'),
      report('2027-01-03T23:59:59+07:00'),
      report('2027-01-04T00:00:00+07:00', 'APPROVED'),
    ],
    new Date('2027-01-04T12:00:00+07:00')
  );

  assert.equal(trend.length, 25);
  assert.equal(trend[0].name, 'Mgu 20/07');
  assert.deepEqual(
    trend.slice(-3),
    [
      { name: 'Mgu 21/12', Laporan: 1, Disetujui: 0 },
      { name: 'Mgu 28/12', Laporan: 2, Disetujui: 1 },
      { name: 'Mgu 04/01', Laporan: 1, Disetujui: 1 },
    ]
  );
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
  assert.match(source, /interval="preserveStartEnd"/);
  assert.match(source, /minTickGap=\{24\}/);
});
