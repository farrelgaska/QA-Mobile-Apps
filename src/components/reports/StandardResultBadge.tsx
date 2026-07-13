import React from 'react';
import { Badge } from '../ui/Badge';
import type { StandardResult, ChecklistResult } from '../../types/report';
import { getStandardResultBadgeVariant } from '../../utils/status';

interface StandardResultBadgeProps {
  result: StandardResult | ChecklistResult;
}

export const StandardResultBadge: React.FC<StandardResultBadgeProps> = ({ result }) => {
  let mappedResult: StandardResult;
  const r = (result as string).toUpperCase();
  if (r === 'PASS' || r === 'LULUS') mappedResult = 'Lulus';
  else if (r === 'FAIL' || r === 'TIDAK LULUS') mappedResult = 'Tidak Lulus';
  else mappedResult = 'Perlu Review';

  const color = getStandardResultBadgeVariant(mappedResult);
  return <Badge color={color}>{mappedResult}</Badge>;
};
