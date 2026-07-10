import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useReports } from '../app/ReportsContext';
import { Card, CardContent } from '../components/ui/Card';
import { Table, TableHeader, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Button } from '../components/ui/Button';
import { ReportStatusBadge } from '../components/reports/ReportStatusBadge';
import { StandardResultBadge } from '../components/reports/StandardResultBadge';
import { Search, Filter } from 'lucide-react';

import { PageTransition } from '../components/layout/PageTransition';
import { motion } from 'framer-motion';

export const ReportsPage: React.FC = () => {
  const navigate = useNavigate();
  const { reports } = useReports();

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [standardFilter, setStandardFilter] = useState('');
  const [locationFilter, setLocationFilter] = useState('');

  // Unique locations for filter
  const locations = Array.from(new Set(reports.map(r => r.locationName))).sort();

  // Filtered reports
  const filteredReports = reports.filter(rep => {
    const q = searchQuery.toLowerCase();
    const matchesSearch =
      rep.title.toLowerCase().includes(q) ||
      rep.id.toLowerCase().includes(q) ||
      rep.submittedBy.toLowerCase().includes(q) ||
      rep.submittedByNik.toLowerCase().includes(q) ||
      rep.locationName.toLowerCase().includes(q);

    const matchesStatus = statusFilter === '' || rep.status === statusFilter;
    const matchesType = typeFilter === '' || rep.type === typeFilter;
    const matchesStandard = standardFilter === '' || rep.standardResult === standardFilter;
    const matchesLocation = locationFilter === '' || rep.locationName === locationFilter;

    return matchesSearch && matchesStatus && matchesType && matchesStandard && matchesLocation;
  });

  const activeFilterCount = [statusFilter, typeFilter, standardFilter, locationFilter].filter(Boolean).length;

  return (
    <PageTransition className="space-y-6 max-w-7xl mx-auto">
      {/* Page Header */}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-xl font-extrabold text-gray-900">Laporan Masuk</h2>
          <p className="text-xs text-gray-500 mt-1">
            Review, evaluasi kelayakan parameter, dan kelola persetujuan laporan QC dari lapangan.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold text-gray-400 bg-gray-100 px-3 py-1.5 rounded-full">
            {filteredReports.length} dari {reports.length} laporan
          </span>
        </div>
      </div>

      {/* Filter Card */}
      <Card className="overflow-visible relative z-30">
        <CardContent className="py-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter className="h-4 w-4 text-gray-400" />
            <span className="text-xs font-bold text-gray-600 uppercase tracking-wider">Filter & Pencarian</span>
            {activeFilterCount > 0 && (
              <span className="inline-flex items-center justify-center h-5 w-5 rounded-full bg-[#006B5A] text-white text-[10px] font-bold">
                {activeFilterCount}
              </span>
            )}
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-5 gap-3">
            {/* Search */}
            <div className="xl:col-span-2">
              <Input
                id="search-report"
                placeholder="Cari ID, judul, staf, NIK, lokasi..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                icon={<Search className="h-4 w-4 text-gray-400" />}
              />
            </div>
            {/* Type filter */}
            <div>
              <Select
                id="type-filter"
                placeholder="Semua Jenis QC"
                value={typeFilter}
                onChange={(val) => setTypeFilter(val)}
                options={[
                  { value: '', label: 'Semua Jenis' },
                  { value: 'material', label: 'QC Material' },
                  { value: 'pekerjaan', label: 'QC Pekerjaan' }
                ]}
              />
            </div>
            {/* Status filter */}
            <div>
              <Select
                id="status-filter"
                placeholder="Semua Status"
                value={statusFilter}
                onChange={(val) => setStatusFilter(val)}
                options={[
                  { value: '', label: 'Semua Status' },
                  { value: 'Draft', label: 'Draft' },
                  { value: 'Menunggu Review', label: 'Menunggu Review' },
                  { value: 'Disetujui', label: 'Disetujui' },
                  { value: 'Perlu Perbaikan', label: 'Perlu Perbaikan' }
                ]}
              />
            </div>
            {/* Standard result filter */}
            <div>
              <Select
                id="standard-filter"
                placeholder="Hasil Standar"
                value={standardFilter}
                onChange={(val) => setStandardFilter(val)}
                options={[
                  { value: '', label: 'Semua Hasil' },
                  { value: 'Lulus', label: 'Lulus' },
                  { value: 'Tidak Lulus', label: 'Tidak Lulus' },
                  { value: 'Perlu Review', label: 'Perlu Review' }
                ]}
              />
            </div>
          </div>
          {/* Location filter row */}
          <div className="mt-3 flex flex-wrap items-center gap-3">
            <div className="w-full sm:w-64">
              <Select
                id="location-filter"
                placeholder="Semua Lokasi"
                value={locationFilter}
                onChange={(val) => setLocationFilter(val)}
                options={[
                  { value: '', label: 'Semua Lokasi' },
                  ...locations.map(loc => ({ value: loc, label: loc }))
                ]}
              />
            </div>
            {activeFilterCount > 0 && (
              <button
                onClick={() => {
                  setSearchQuery('');
                  setStatusFilter('');
                  setTypeFilter('');
                  setStandardFilter('');
                  setLocationFilter('');
                }}
                className="text-xs font-semibold text-gray-500 hover:text-[#006B5A] transition-colors"
              >
                Hapus semua filter ×
              </button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Table */}
      <Card className="relative z-0 min-h-[320px] w-full overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-sm">
        <CardContent className="p-0">
          <motion.div
            key={`${statusFilter}-${typeFilter}-${standardFilter}-${locationFilter}-${searchQuery}`}
            className="w-full"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            layout={false}
          >
            <Table className="w-full table-fixed">
              <colgroup>
                <col className="w-[11%]" />
                <col className="w-[11%]" />
                <col className="w-[22%]" />
                <col className="w-[14%]" />
                <col className="w-[13%]" />
                <col className="w-[10%]" />
                <col className="w-[9%]" />
                <col className="w-[10%]" />
                <col className="w-[10%]" />
              </colgroup>
              <TableHeader>
                <TableRow>
                  <TableCell isHeader className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">ID Laporan</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Jenis QC</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Judul Laporan</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Lokasi</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Dibuat Oleh</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-left text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Tanggal Submit</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-center text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Status</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-center text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Hasil Standar</TableCell>
                  <TableCell isHeader className="px-6 py-4 text-center text-xs font-bold uppercase tracking-wide text-gray-500 align-middle">Aksi</TableCell>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredReports.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={9} className="text-center py-12 text-gray-400 italic">
                      Tidak ada laporan yang cocok dengan filter aktif.
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredReports.map((rep) => (
                    <TableRow key={rep.id} className="hover:bg-gray-50/60 cursor-pointer group" onClick={() => navigate(`/laporan/${rep.id}`)}>
                      {/* ID */}
                      <TableCell className="font-mono text-xs font-bold text-[#006B5A] px-6 py-5 align-middle">
                        {rep.id}
                      </TableCell>
                      {/* Type */}
                      <TableCell className="px-6 py-5 align-middle">
                        <span className={`inline-flex items-center text-xs font-semibold px-2 py-0.5 rounded-full border whitespace-nowrap ${
                          rep.type === 'material'
                            ? 'bg-blue-50 text-blue-700 border-blue-200/60'
                            : 'bg-violet-50 text-violet-700 border-violet-200/60'
                        }`}>
                          {rep.type === 'material' ? 'Material' : 'Pekerjaan'}
                        </span>
                      </TableCell>
                      {/* Title */}
                      <TableCell className="px-6 py-5 align-middle min-w-0">
                        <div className="min-w-0">
                          <p className="line-clamp-2 font-semibold text-gray-800 text-sm leading-tight">{rep.title}</p>
                          <p className="text-xs text-gray-400 mt-0.5">{rep.checklistItems.length} parameter checklist</p>
                        </div>
                      </TableCell>
                      {/* Location */}
                      <TableCell className="px-6 py-5 align-middle min-w-0">
                        <p className="text-sm text-gray-600 font-medium line-clamp-2">{rep.locationName}</p>
                      </TableCell>
                      {/* Staff */}
                      <TableCell className="px-6 py-5 align-middle min-w-0">
                        <p className="text-sm font-semibold text-gray-700 truncate">{rep.submittedBy}</p>
                        <p className="text-xs text-gray-400 font-mono">{rep.submittedByNik}</p>
                      </TableCell>
                      {/* Date */}
                      <TableCell className="px-6 py-5 align-middle">
                        <p className="text-xs font-semibold text-gray-600">
                          {new Date(rep.submittedAt).toLocaleDateString('id-ID', {
                            day: 'numeric', month: 'short', year: 'numeric'
                          })}
                        </p>
                        <p className="text-[11px] text-gray-400">
                          {new Date(rep.submittedAt).toLocaleTimeString('id-ID', {
                            hour: '2-digit', minute: '2-digit'
                          })}
                        </p>
                      </TableCell>
                      {/* Status */}
                      <TableCell className="text-center px-6 py-5 align-middle">
                        <div className="flex justify-center whitespace-nowrap">
                          <ReportStatusBadge status={rep.status} />
                        </div>
                      </TableCell>
                      {/* Standard Result */}
                      <TableCell className="text-center px-6 py-5 align-middle">
                        <div className="flex justify-center whitespace-nowrap">
                          <StandardResultBadge result={rep.standardResult} />
                        </div>
                      </TableCell>
                      {/* Action */}
                      <TableCell className="text-center px-6 py-5 align-middle" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-center">
                          <Button
                            id={`detail-btn-${rep.id}`}
                            size="sm"
                            variant="outline"
                            onClick={() => navigate(`/laporan/${rep.id}`)}
                            className="text-xs hover:border-[#006B5A] hover:text-[#006B5A] hover:bg-[#006B5A]/5 min-w-[92px]"
                          >
                            Detail →
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </motion.div>

          {/* Footer count */}
          {filteredReports.length > 0 && (
            <div className="px-6 py-3 border-t border-gray-50 bg-gray-50/30">
              <p className="text-xs text-gray-400">
                Menampilkan <span className="font-semibold text-gray-600">{filteredReports.length}</span> dari{' '}
                <span className="font-semibold text-gray-600">{reports.length}</span> laporan
              </p>
            </div>
          )}
        </CardContent>
      </Card>
    </PageTransition>
  );
};
