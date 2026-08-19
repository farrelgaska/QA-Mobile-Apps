import React from 'react';
import type { QCReport } from '../../types/report';
import { inspectionInformationRows } from '../../utils/materialReportPresentation';
import { Card, CardContent } from '../ui/Card';

export const InspectionInformation: React.FC<{ report: QCReport }> = ({
  report,
}) => {
  const rows = inspectionInformationRows(report);

  return (
    <Card title="Informasi Inspeksi">
      <CardContent className="pt-3">
        {rows.length === 0 ? (
          <p className="py-6 text-center text-xs italic text-gray-400">
            Informasi inspeksi tidak tersedia pada laporan ini.
          </p>
        ) : (
          <dl className="divide-y divide-gray-100">
            {rows.map(row => (
              <div key={row.field} className="py-3 first:pt-0 last:pb-0">
                <dt className="text-[11px] font-semibold uppercase tracking-wider text-gray-400">
                  {row.label}
                </dt>
                <dd className="mt-1 break-words text-sm font-semibold text-gray-800">
                  {row.value}
                </dd>
              </div>
            ))}
          </dl>
        )}
      </CardContent>
    </Card>
  );
};
