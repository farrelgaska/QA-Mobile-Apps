import type { ReportStatus } from '../types/report';

export const RECENT_REPORT_WEEK_COUNT = 6;

export interface ReportTrendInput {
  submittedAt: string;
  status: ReportStatus;
}

export interface WeeklyReportTrendPoint {
  name: string;
  Laporan: number;
  Disetujui: number;
}

const startOfLocalWeek = (value: Date): Date => {
  const monday = new Date(value);
  const day = monday.getDay();
  monday.setDate(monday.getDate() - day + (day === 0 ? -6 : 1));
  monday.setHours(0, 0, 0, 0);
  return monday;
};

const weekKey = (monday: Date): string => [
  monday.getFullYear(),
  String(monday.getMonth() + 1).padStart(2, '0'),
  String(monday.getDate()).padStart(2, '0'),
].join('-');

const weekLabel = (monday: Date): string => {
  const day = String(monday.getDate()).padStart(2, '0');
  const month = String(monday.getMonth() + 1).padStart(2, '0');
  return `Mgu ${day}/${month}`;
};

export const buildRecentWeeklyReportTrend = (
  reports: readonly ReportTrendInput[],
  now: Date = new Date()
): WeeklyReportTrendPoint[] => {
  const latestMonday = startOfLocalWeek(now);
  const weeks = Array.from({ length: RECENT_REPORT_WEEK_COUNT }, (_, index) => {
    const monday = new Date(latestMonday);
    monday.setDate(
      latestMonday.getDate() -
        (RECENT_REPORT_WEEK_COUNT - index - 1) * 7
    );
    return {
      key: weekKey(monday),
      point: {
        name: weekLabel(monday),
        Laporan: 0,
        Disetujui: 0,
      },
    };
  });
  const pointsByWeek = new Map(
    weeks.map(({ key, point }) => [key, point])
  );

  reports.forEach(report => {
    if (!report.submittedAt) return;
    const submittedAt = new Date(report.submittedAt);
    if (Number.isNaN(submittedAt.getTime())) return;

    const point = pointsByWeek.get(weekKey(startOfLocalWeek(submittedAt)));
    if (!point) return;

    point.Laporan += 1;
    if (report.status === 'APPROVED') {
      point.Disetujui += 1;
    }
  });

  return weeks.map(({ point }) => point);
};
