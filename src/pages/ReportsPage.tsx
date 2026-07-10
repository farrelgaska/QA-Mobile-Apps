import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useReports } from '../app/ReportsContext';
import { Card, CardContent } from '../components/ui/Card';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { ReportTable } from '../components/reports/ReportTable';
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
      <div className="relative z-0 min-h-[320px] w-full">
        <motion.div
          key={`${statusFilter}-${typeFilter}-${standardFilter}-${locationFilter}-${searchQuery}`}
          className="w-full"
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.18 }}
          layout={false}
        >
          <ReportTable
            reports={filteredReports}
            onDetail={(id) => navigate(`/laporan/${id}`)}
          />
        </motion.div>

        {/* Footer count */}
        {filteredReports.length > 0 && (
          <div className="px-6 py-3 mt-3 border border-slate-200 rounded-2xl bg-white shadow-sm">
            <p className="text-xs text-gray-400">
              Menampilkan <span className="font-semibold text-gray-600">{filteredReports.length}</span> dari{' '}
              <span className="font-semibold text-gray-600">{reports.length}</span> laporan
            </p>
          </div>
        )}
      </div>
    </PageTransition>
  );
};
