import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useReports } from '../app/ReportsContext';
import { Card, CardContent } from '../components/ui/Card';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { ReportTable } from '../components/reports/ReportTable';
import { Search, Filter, AlertTriangle, RefreshCw, ClipboardList } from 'lucide-react';
import { Button } from '../components/ui/Button';
import { PageTransition } from '../components/layout/PageTransition';
import { motion } from 'framer-motion';

// ─── Loading skeleton ─────────────────────────────────────────────────────────

const TableSkeleton: React.FC = () => (
  <div className="space-y-3 mt-2 animate-pulse">
    {[...Array(5)].map((_, i) => (
      <div key={i} className="h-14 rounded-xl bg-gray-100" />
    ))}
  </div>
);

// ─── Error state ─────────────────────────────────────────────────────────────

const ErrorState: React.FC<{ message: string; onRetry: () => void }> = ({ message, onRetry }) => (
  <div className="flex flex-col items-center justify-center py-16 gap-4 text-center">
    <div className="h-14 w-14 rounded-2xl bg-rose-50 border border-rose-200 flex items-center justify-center">
      <AlertTriangle className="h-7 w-7 text-rose-500" />
    </div>
    <div>
      <p className="font-bold text-gray-700">Gagal memuat laporan</p>
      <p className="text-sm text-gray-400 mt-1 max-w-xs leading-relaxed">{message}</p>
    </div>
    <Button variant="outline" onClick={onRetry} className="mt-1">
      <RefreshCw className="h-4 w-4 mr-2" />
      Coba Lagi
    </Button>
  </div>
);

// ─── Empty state ─────────────────────────────────────────────────────────────

const EmptyState: React.FC<{ hasFilters: boolean; onClear: () => void }> = ({ hasFilters, onClear }) => (
  <div className="flex flex-col items-center justify-center py-16 gap-3 text-center">
    <div className="h-14 w-14 rounded-2xl bg-gray-100 border border-gray-200 flex items-center justify-center">
      <ClipboardList className="h-7 w-7 text-gray-400" />
    </div>
    <div>
      <p className="font-bold text-gray-600">{hasFilters ? 'Tidak ada laporan yang cocok' : 'Belum ada laporan masuk'}</p>
      <p className="text-sm text-gray-400 mt-1">
        {hasFilters
          ? 'Coba ubah atau hapus filter pencarian.'
          : 'Laporan dari staf lapangan akan muncul di sini setelah dikirim.'}
      </p>
    </div>
    {hasFilters && (
      <Button variant="outline" onClick={onClear} className="mt-1 text-sm">
        Hapus Semua Filter
      </Button>
    )}
  </div>
);

// ─── Page ─────────────────────────────────────────────────────────────────────

export const ReportsPage: React.FC = () => {
  const navigate = useNavigate();
  const { reports, loading, error, refetch } = useReports();

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [standardFilter, setStandardFilter] = useState('');
  const [locationFilter, setLocationFilter] = useState('');

  const clearFilters = () => {
    setSearchQuery('');
    setStatusFilter('');
    setTypeFilter('');
    setStandardFilter('');
    setLocationFilter('');
  };

  // Unique locations for filter dropdown
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
  const hasFilters = activeFilterCount > 0 || searchQuery !== '';

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
          {/* Offline warning badge */}
          {error && !loading && (
            <span className="text-[11px] font-semibold text-amber-700 bg-amber-50 border border-amber-200 px-3 py-1.5 rounded-full">
              ⚠ Mode Offline
            </span>
          )}
          <span className="text-xs font-semibold text-gray-400 bg-gray-100 px-3 py-1.5 rounded-full">
            {loading ? '…' : `${filteredReports.length} dari ${reports.length} laporan`}
          </span>
          <button
            title="Muat ulang laporan"
            onClick={refetch}
            className="h-8 w-8 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-colors"
            disabled={loading}
          >
            <RefreshCw className={`h-3.5 w-3.5 text-gray-500 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Filter Card */}
      <Card className="overflow-visible relative z-30">
        <CardContent className="py-4">
          <div className="flex items-center gap-2 mb-3">
            <Filter className="h-4 w-4 text-gray-400" />
            <span className="text-xs font-bold text-gray-600 uppercase tracking-wider">Filter &amp; Pencarian</span>
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
                  { value: 'SUBMITTED', label: 'Menunggu Review' },
                  { value: 'APPROVED', label: 'Disetujui' },
                  { value: 'NEEDS_FOLLOW_UP', label: 'Perlu Tindak Lanjut' }
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
            {hasFilters && (
              <button
                onClick={clearFilters}
                className="text-xs font-semibold text-gray-500 hover:text-[#006B5A] transition-colors"
              >
                Hapus semua filter ×
              </button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Content area */}
      <div className="relative z-0 min-h-[320px] w-full">
        {loading ? (
          <TableSkeleton />
        ) : error && reports.length === 0 ? (
          <ErrorState message={error} onRetry={refetch} />
        ) : (
          <motion.div
            key={`${statusFilter}-${typeFilter}-${standardFilter}-${locationFilter}-${searchQuery}`}
            className="w-full"
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.18 }}
            layout={false}
          >
            {filteredReports.length === 0 ? (
              <EmptyState hasFilters={hasFilters} onClear={clearFilters} />
            ) : (
              <>
                <ReportTable
                  reports={filteredReports}
                  onDetail={(id) => navigate(`/laporan/${id}`)}
                />
                {/* Footer count */}
                <div className="px-6 py-3 mt-3 border border-slate-200 rounded-2xl bg-white shadow-sm">
                  <p className="text-xs text-gray-400">
                    Menampilkan <span className="font-semibold text-gray-600">{filteredReports.length}</span> dari{' '}
                    <span className="font-semibold text-gray-600">{reports.length}</span> laporan
                  </p>
                </div>
              </>
            )}
          </motion.div>
        )}
      </div>
    </PageTransition>
  );
};
