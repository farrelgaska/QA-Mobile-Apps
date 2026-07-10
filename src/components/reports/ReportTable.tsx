import React from 'react';
import type { QCReport } from '../../types/report';
import { ReportStatusBadge } from './ReportStatusBadge';
import { StandardResultBadge } from './StandardResultBadge';

export interface ReportTableProps {
  reports: QCReport[];
  onDetail?: (id: string) => void;
}

export const ReportTable: React.FC<ReportTableProps> = ({ reports, onDetail }) => {
  return (
    <div className="w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div className="w-full overflow-x-auto">
        <table className="w-full min-w-[1180px] table-fixed border-collapse">
          <colgroup>
            <col className="w-[8%]" />
            <col className="w-[9%]" />
            <col className="w-[23%]" />
            <col className="w-[12%]" />
            <col className="w-[12%]" />
            <col className="w-[10%]" />
            <col className="w-[10%]" />
            <col className="w-[10%]" />
            <col className="w-[10%]" />
          </colgroup>

          <thead>
            <tr className="bg-gray-50 border-b border-slate-200">
              <th className="px-6 py-4 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                ID Laporan
              </th>
              <th className="px-6 py-4 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Jenis QC
              </th>
              <th className="px-6 py-4 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Judul Laporan
              </th>
              <th className="px-6 py-4 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Lokasi
              </th>
              <th className="px-6 py-4 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Dibuat Oleh
              </th>
              <th className="px-6 py-4 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Tanggal Submit
              </th>
              <th className="px-6 py-4 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Status
              </th>
              <th className="px-6 py-4 pr-8 text-left align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Hasil Standar
              </th>
              <th className="px-6 py-4 pl-8 text-center align-middle text-xs font-bold uppercase tracking-wide text-slate-500">
                Aksi
              </th>
            </tr>
          </thead>

          <tbody className="divide-y divide-slate-100 bg-white">
            {reports.length === 0 ? (
              <tr>
                <td colSpan={9} className="px-6 py-12 text-center text-sm text-slate-400 italic">
                  Tidak ada laporan yang cocok dengan filter aktif.
                </td>
              </tr>
            ) : (
              reports.map((report) => (
                <tr
                  key={report.id}
                  onClick={() => onDetail?.(report.id)}
                  className="cursor-pointer hover:bg-gray-50/50 transition-colors duration-150 group"
                >
                  {/* ID */}
                  <td className="px-6 py-5 align-middle text-sm text-slate-700 font-mono font-bold text-[#006B5A]">
                    {report.id}
                  </td>

                  {/* Jenis QC */}
                  <td className="px-6 py-5 align-middle text-sm text-slate-700">
                    <span
                      className={`inline-flex items-center text-xs font-semibold px-2 py-0.5 rounded-full border whitespace-nowrap ${
                        report.type === 'material'
                          ? 'bg-blue-50 text-blue-700 border-blue-200/60'
                          : 'bg-violet-50 text-violet-700 border-violet-200/60'
                      }`}
                    >
                      {report.type === 'material' ? 'Material' : 'Pekerjaan'}
                    </span>
                  </td>

                  {/* Judul Laporan */}
                  <td className="px-6 py-5 align-middle text-sm text-slate-700 min-w-0">
                    <div className="min-w-0">
                      <p className="line-clamp-2 font-semibold leading-snug text-slate-900">
                        {report.title}
                      </p>
                      <p className="mt-1 text-xs text-slate-400">
                        {report.checklistItems ? report.checklistItems.length : 0} parameter checklist
                      </p>
                    </div>
                  </td>

                  {/* Lokasi */}
                  <td className="px-6 py-5 align-middle text-sm text-slate-700 min-w-0">
                    <p className="line-clamp-2 leading-snug text-slate-600 font-medium">
                      {report.locationName}
                    </p>
                  </td>

                  {/* Dibuat Oleh */}
                  <td className="px-6 py-5 align-middle text-sm text-slate-700 min-w-0">
                    <div className="min-w-0">
                      <p className="font-semibold text-slate-700 truncate">{report.submittedBy}</p>
                      <p className="text-xs text-slate-400 font-mono">{report.submittedByNik}</p>
                    </div>
                  </td>

                  {/* Tanggal Submit */}
                  <td className="px-6 py-5 align-middle text-sm text-slate-700">
                    <p className="text-xs font-semibold text-slate-600">
                      {new Date(report.submittedAt).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </p>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      {new Date(report.submittedAt).toLocaleTimeString('id-ID', {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </p>
                  </td>

                  {/* Status */}
                  <td className="px-6 py-5 align-middle text-sm text-slate-700">
                    <div className="flex items-center whitespace-nowrap">
                      <ReportStatusBadge status={report.status} />
                    </div>
                  </td>

                  {/* Hasil Standar */}
                  <td className="px-6 py-5 pr-8 align-middle text-sm text-slate-700">
                    <div className="flex items-center whitespace-nowrap">
                      <StandardResultBadge result={report.standardResult} />
                    </div>
                  </td>

                  {/* Aksi */}
                  <td className="px-6 py-5 pl-8 align-middle text-center" onClick={(e) => e.stopPropagation()}>
                    <div className="flex justify-center">
                      <button
                        onClick={() => onDetail?.(report.id)}
                        className="inline-flex min-h-[44px] min-w-[96px] items-center justify-center rounded-xl border border-slate-200 px-4 py-2 text-sm font-semibold bg-white text-gray-700 hover:border-[#006B5A] hover:text-[#006B5A] hover:bg-[#006B5A]/5 transition-all active:scale-[0.98]"
                      >
                        Detail →
                      </button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
