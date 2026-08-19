import type { ReportStatus } from '../types/report';

export interface ReportTrendInput {
  submittedAt: string;
  status: ReportStatus;
  admin_review?: {
    reviewed_at?: string;
  };
}

export interface WeeklyReportTrendPoint {
  name: string;
  Laporan: number;
  Disetujui: number;
}

const JAKARTA_TIME_ZONE = 'Asia/Jakarta';
const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;
const REPORT_TREND_START_DAY = Date.UTC(2026, 6, 20) / MILLISECONDS_PER_DAY;
const jakartaDateFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: JAKARTA_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

const parseReportDate = (value: string): Date | null => {
  if (!value) return null;

  // The API emits ISO timestamps with an offset. Treat legacy offset-less
  // date-times as Jakarta wall-clock values instead of using the browser zone.
  const normalized = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(value)
    && !/(?:Z|[+-]\d{2}:?\d{2})$/i.test(value)
    ? `${value}+07:00`
    : value;
  const parsed = new Date(normalized);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const jakartaCalendarDay = (value: Date): number => {
  const parts = Object.fromEntries(
    jakartaDateFormatter.formatToParts(value).map(part => [part.type, part.value])
  );
  return Date.UTC(Number(parts.year), Number(parts.month) - 1, Number(parts.day))
    / MILLISECONDS_PER_DAY;
};

const startOfJakartaWeek = (value: Date): number => {
  const calendarDay = jakartaCalendarDay(value);
  const dayOfWeek = new Date(calendarDay * MILLISECONDS_PER_DAY).getUTCDay();
  return calendarDay - (dayOfWeek === 0 ? 6 : dayOfWeek - 1);
};

const weekKey = (mondayDay: number): string => {
  const monday = new Date(mondayDay * MILLISECONDS_PER_DAY);
  return [
    monday.getUTCFullYear(),
    String(monday.getUTCMonth() + 1).padStart(2, '0'),
    String(monday.getUTCDate()).padStart(2, '0'),
  ].join('-');
};

const weekLabel = (mondayDay: number): string => {
  const monday = new Date(mondayDay * MILLISECONDS_PER_DAY);
  const day = String(monday.getUTCDate()).padStart(2, '0');
  const month = String(monday.getUTCMonth() + 1).padStart(2, '0');
  return `Mgu ${day}/${month}`;
};

export const buildRecentWeeklyReportTrend = (
  reports: readonly ReportTrendInput[],
  now: Date = new Date()
): WeeklyReportTrendPoint[] => {
  const currentMonday = startOfJakartaWeek(now);
  const weekCount = Math.max(
    0,
    Math.floor((currentMonday - REPORT_TREND_START_DAY) / 7) + 1
  );
  const weeks = Array.from({ length: weekCount }, (_, index) => {
    const monday = REPORT_TREND_START_DAY + index * 7;
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
    const submittedAt = parseReportDate(report.submittedAt);
    if (!submittedAt || submittedAt.getTime() > now.getTime()) return;

    const submittedWeek = startOfJakartaWeek(submittedAt);
    if (submittedWeek < REPORT_TREND_START_DAY) return;

    const submittedPoint = pointsByWeek.get(
      weekKey(submittedWeek)
    );
    if (!submittedPoint) return;
    submittedPoint.Laporan += 1;

    if (report.status === 'APPROVED') {
      // reviewed_at is the canonical approval timestamp. Older reports may not
      // have it, so their submission timestamp is the most accurate fallback.
      const approvedAt = parseReportDate(report.admin_review?.reviewed_at ?? '')
        ?? submittedAt;
      if (approvedAt.getTime() > now.getTime()) return;
      const approvedPoint = pointsByWeek.get(
        weekKey(startOfJakartaWeek(approvedAt))
      );
      if (approvedPoint) approvedPoint.Disetujui += 1;
    }
  });

  return weeks.map(({ point }) => point);
};
