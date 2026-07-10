import React from 'react';
import { Badge } from '../ui/Badge';
import type { StandardResult, ChecklistResult } from '../../types/report';
import { getStandardResultBadgeVariant } from '../../utils/status';

interface StandardResultBadgeProps {
  result: StandardResult | ChecklistResult;
}

export const StandardResultBadge: React.FC<StandardResultBadgeProps> = ({ result }) => {
  let mappedResult: StandardResult;
  if (result === 'pass') mappedResult = 'Lulus';
  else if (result === 'fail') mappedResult = 'Tidak Lulus';
  else if (result === 'review') mappedResult = 'Perlu Review';
  else mappedResult = result;

  const color = getStandardResultBadgeVariant(mappedResult);
  return <Badge color={color}>{mappedResult}</Badge>;
};
