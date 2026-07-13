import type { ReportStatus, StandardResult } from '../types/report';

export const STATUS_LABELS: Record<ReportStatus, string> = {
  DRAFT: 'Draft',
  SUBMITTED: 'Menunggu Review',
  NEEDS_FOLLOW_UP: 'Perlu Tindak Lanjut',
  APPROVED: 'Disetujui',
};

export const STATUS_BADGE_VARIANTS: Record<ReportStatus, 'gray' | 'yellow' | 'red' | 'green'> = {
  DRAFT: 'gray',
  SUBMITTED: 'yellow',
  NEEDS_FOLLOW_UP: 'red',
  APPROVED: 'green',
};

export const STATUS_COLORS: Record<ReportStatus, string> = {
  DRAFT: '#6B7280',
  SUBMITTED: '#F5A400',
  NEEDS_FOLLOW_UP: '#DC2626',
  APPROVED: '#16A765',
};

// Normalization function to handle legacy values
export function normalizeReportStatus(status: any): ReportStatus {
  if (!status) return 'DRAFT';
  const val = status.toString().toUpperCase().trim();
  if (val === 'DRAFT') return 'DRAFT';
  if (val === 'SUBMITTED' || val === 'WAITING' || val === 'MENUNGGU REVIEW' || val === 'MENUNGGU' || val === 'PENDING') {
    return 'SUBMITTED';
  }
  if (val === 'NEEDS_FOLLOW_UP' || val === 'NEEDFOLLOWUP' || val === 'NEED_FOLLOW_UP' || val === 'REVISION' || val === 'REVISI' || val === 'PERLU PERBAIKAN' || val === 'PERLU TINDAK LANJUT' || val === 'DITOLAK') {
    return 'NEEDS_FOLLOW_UP';
  }
  if (val === 'APPROVED' || val === 'DISETUJUI' || val === 'LULUS' || val === 'SELESAI') {
    return 'APPROVED';
  }
  return 'DRAFT';
}

export function getReportStatusLabel(status: ReportStatus): string {
  return STATUS_LABELS[status] || status;
}

export function getReportStatusBadgeVariant(status: ReportStatus): 'green' | 'yellow' | 'red' | 'gray' {
  return STATUS_BADGE_VARIANTS[status] || 'gray';
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
  return STATUS_COLORS[status] || '#6B7280';
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
