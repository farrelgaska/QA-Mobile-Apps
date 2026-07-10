import React from 'react';
import type { QCReport } from '../../types/report';
import { Table, TableHeader, TableRow, TableCell, TableBody } from '../ui/Table';
import { ReportStatusBadge } from './ReportStatusBadge';
import { StandardResultBadge } from './StandardResultBadge';
import { Button } from '../ui/Button';
import { formatDate } from '../../utils/formatDate';

export interface ReportTableProps {
  reports: QCReport[];
  onDetail?: (id: string) => void;
}

export const ReportTable: React.FC<ReportTableProps> = ({ reports, onDetail }) => {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableCell isHeader>ID Laporan</TableCell>
          <TableCell isHeader>Item QC</TableCell>
          <TableCell isHeader>Lokasi</TableCell>
          <TableCell isHeader>QA Staff</TableCell>
          <TableCell isHeader>Tanggal Kirim</TableCell>
          <TableCell isHeader>Evaluasi</TableCell>
          <TableCell isHeader>Status</TableCell>
          {onDetail && <TableCell isHeader className="text-right">Aksi</TableCell>}
        </TableRow>
      </TableHeader>
      <TableBody>
        {reports.length === 0 ? (
          <TableRow>
            <TableCell colSpan={onDetail ? 8 : 7} className="text-center py-8 text-gray-400">
              Tidak ada data laporan.
            </TableCell>
          </TableRow>
        ) : (
          reports.map((report) => (
            <TableRow 
              key={report.id}
              className={onDetail ? 'cursor-pointer hover:bg-gray-50/50' : ''}
              onClick={() => onDetail?.(report.id)}
            >
              <TableCell className="font-bold text-gray-800">{report.id}</TableCell>
              <TableCell className="font-semibold text-gray-700">{report.title}</TableCell>
              <TableCell className="text-gray-500">{report.locationName}</TableCell>
              <TableCell className="text-gray-650">
                <div className="font-semibold text-gray-700">{report.submittedBy}</div>
                <div className="text-[10px] text-gray-400 font-semibold">{report.submittedByNik}</div>
              </TableCell>
              <TableCell className="text-gray-500">{formatDate(report.submittedAt)}</TableCell>
              <TableCell>
                <StandardResultBadge result={report.standardResult} />
              </TableCell>
              <TableCell>
                <ReportStatusBadge status={report.status} />
              </TableCell>
              {onDetail && (
                <TableCell className="text-right" onClick={(e) => e.stopPropagation()}>
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => onDetail(report.id)}
                  >
                    Detail
                  </Button>
                </TableCell>
              )}
            </TableRow>
          ))
        )}
      </TableBody>
    </Table>
  );
};
