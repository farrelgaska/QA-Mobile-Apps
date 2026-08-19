import type { QCReport } from '../types/report';

export interface WorkQcDataRow {
  label: string;
  value: string;
}

const displayValue = (value: unknown): string =>
  typeof value === 'string' && value.trim() ? value.trim() : '-';

export const workQcDataRows = (
  report: Pick<QCReport, 'location' | 'general_info'>
): WorkQcDataRow[] => [
  {
    label: 'Lokasi Site (Aktif)',
    value: displayValue(report.location?.site_name),
  },
  {
    label: 'Area / Zona Kerja',
    value: displayValue(report.location?.area),
  },
  {
    label: 'Detail Lokasi / Koordinat',
    value: displayValue(report.location?.detail_location),
  },
  {
    label: 'Nama Mitra Pelaksana',
    value: displayValue(report.general_info?.mitraName),
  },
];
