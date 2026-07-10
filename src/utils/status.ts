import type { ReportStatus, StandardResult } from '../types/report';

export function getReportStatusBadgeVariant(status: ReportStatus): 'green' | 'yellow' | 'red' | 'gray' {
  switch (status) {
    case 'Disetujui':
      return 'green';
    case 'Menunggu Review':
      return 'yellow';
    case 'Perlu Perbaikan':
      return 'red';
    case 'Draft':
    default:
      return 'gray';
  }
}

export function getStandardResultBadgeVariant(result: StandardResult): 'green' | 'yellow' | 'red' | 'gray' {
  switch (result) {
    case 'Lulus':
      return 'green';
    case 'Tidak Lulus':
      return 'red';
    case 'Perlu Review':
    default:
      return 'yellow';
  }
}

export function getStatusColor(status: ReportStatus): string {
  switch (status) {
    case 'Disetujui':
      return '#16A765';
    case 'Menunggu Review':
      return '#F5A400';
    case 'Perlu Perbaikan':
      return '#DC2626';
    case 'Draft':
    default:
      return '#6B7280';
  }
}

export function getStandardResultColor(result: StandardResult): string {
  switch (result) {
    case 'Lulus':
      return '#16A765';
    case 'Tidak Lulus':
      return '#DC2626';
    case 'Perlu Review':
    default:
      return '#F5A400';
  }
}
