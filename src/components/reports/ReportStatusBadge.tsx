import React from 'react';
import { Badge } from '../ui/Badge';
import type { ReportStatus } from '../../types/report';
import { getReportStatusBadgeVariant } from '../../utils/status';

interface ReportStatusBadgeProps {
  status: ReportStatus;
}

export const ReportStatusBadge: React.FC<ReportStatusBadgeProps> = ({ status }) => {
  const color = getReportStatusBadgeVariant(status);
  return <Badge color={color}>{status}</Badge>;
};
