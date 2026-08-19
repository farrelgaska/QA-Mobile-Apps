import React from 'react';
import { Badge } from '../ui/Badge';
import type { ReportStatus } from '../../types/report';
import { getReportStatusBadgeVariant, getReportStatusLabel } from '../../utils/status';

interface ReportStatusBadgeProps {
  status: ReportStatus;
}

export const ReportStatusBadge: React.FC<ReportStatusBadgeProps> = ({ status }) => {
  const color = getReportStatusBadgeVariant(status);
  const label = getReportStatusLabel(status);
  return <Badge color={color}>{label}</Badge>;
};
