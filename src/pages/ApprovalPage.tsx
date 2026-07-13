import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useReports } from '../app/ReportsContext';
import { PageTransition } from '../components/layout/PageTransition';
import type { QCReport, ChecklistItem } from '../types/report';
import { Card, CardContent } from '../components/ui/Card';
import { motion } from 'framer-motion';
import { Table, TableHeader, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Modal } from '../components/ui/Modal';
import { StandardResultBadge } from '../components/reports/StandardResultBadge';
import {
  Search,
  CheckCircle,
  RefreshCw,
  Eye,
  Clock,
  FileText,
  CheckCheck,
  AlertCircle,
} from 'lucide-react';

// ─── Toast-style feedback ────────────────────────────────────────────────────

interface Toast {
  id: string;
  type: 'success' | 'error';
  message: string;
}

export const ApprovalPage: React.FC = () => {
  const navigate = useNavigate();
  const { reports, approveReport, requestRevision } = useReports();

  // Only show "SUBMITTED" reports
  const pendingReports = reports.filter(r => r.status === 'SUBMITTED');

  // Search & Filter
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('');

  // Approve modal state
  const [approveTarget, setApproveTarget] = useState<QCReport | null>(null);
  const [approveNote, setApproveNote] = useState('');

  // Revision modal state
  const [revisionTarget, setRevisionTarget] = useState<QCReport | null>(null);
  const [revisionNote, setRevisionNote] = useState('');

  // Toast feedback
  const [toasts, setToasts] = useState<Toast[]>([]);

  const showToast = (type: 'success' | 'error', message: string) => {
    const id = `${Date.now()}`;
    setToasts(prev => [...prev, { id, type, message }]);
    setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 3500);
  };

  // Filtered pending
  const filtered = pendingReports.filter(rep => {
    const q = searchQuery.toLowerCase();
    const matchSearch =
      rep.title.toLowerCase().includes(q) ||
      rep.id.toLowerCase().includes(q) ||
      rep.submittedBy.toLowerCase().includes(q) ||
      rep.locationName.toLowerCase().includes(q);
    const matchType = typeFilter === '' || rep.type === typeFilter;
    return matchSearch && matchType;
  });

  // Handle Approve
  const handleApproveConfirm = () => {
    if (!approveTarget) return;
    approveReport(approveTarget.id, approveNote || undefined);
    showToast('success', `Laporan ${approveTarget.id} berhasil disetujui.`);
    setApproveTarget(null);
    setApproveNote('');
  };

  // Handle Revision
  const handleRevisionConfirm = () => {
    if (!revisionTarget || !revisionNote.trim()) return;
    requestRevision(revisionTarget.id, revisionNote.trim());
    showToast('error', `Laporan ${revisionTarget.id} dikembalikan untuk perbaikan.`);
    setRevisionTarget(null);
    setRevisionNote('');
  };

  return (
    <PageTransition className="space-y-6 max-w-7xl mx-auto">

      {/* ── Toast Notifications ──────────────────── */}
      <div className="fixed top-5 right-5 z-[100] flex flex-col gap-2 pointer-events-none">
        {toasts.map(t => (
          <div
            key={t.id}
            className={`flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg border text-sm font-semibold animate-fadeIn pointer-events-auto transition-all duration-300 ${
              t.type === 'success'
                ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
                : 'bg-rose-50 border-rose-200 text-rose-800'
            }`}
          >
            {t.type === 'success'
              ? <CheckCheck className="h-4 w-4 text-emerald-600 flex-shrink-0" />
              : <AlertCircle className="h-4 w-4 text-rose-500 flex-shrink-0" />}
            {t.message}
          </div>
        ))}
      </div>

      {/* ── Header ───────────────────────────────── */}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-xl font-extrabold text-gray-900">Antrean Approval</h2>
          <p className="text-xs text-gray-500 mt-1">
            Laporan dari lapangan yang menunggu evaluasi dan keputusan admin.
          </p>
        </div>
        <div className="flex items-center gap-2">
          {pendingReports.length > 0 ? (
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-amber-50 border border-amber-200 text-amber-800 text-xs font-bold rounded-full">
              <span className="flex h-2 w-2 relative">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-500" />
              </span>
              {pendingReports.length} menunggu review
            </span>
          ) : (
            <span className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 border border-emerald-200 text-emerald-700 text-xs font-bold rounded-full">
              <CheckCheck className="h-3.5 w-3.5" />
              Semua laporan sudah ditangani
            </span>
          )}
        </div>
      </div>

      {/* ── Filters ──────────────────────────────── */}
      <Card className="overflow-visible relative z-30">
        <CardContent className="py-4">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div className="md:col-span-2">
              <Input
                id="search-approval"
                placeholder="Cari ID, judul, nama staf, lokasi..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                icon={<Search className="h-4 w-4 text-gray-400" />}
              />
            </div>
            <div>
              <Select
                id="type-filter-approval"
                placeholder="Semua Jenis QC"
                value={typeFilter}
                onChange={(val) => setTypeFilter(val)}
                options={[
                  { value: '', label: 'Semua Jenis QC' },
                  { value: 'material', label: 'QC Material' },
                  { value: 'pekerjaan', label: 'QC Pekerjaan' },
                ]}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* ── Table ────────────────────────────────── */}
      <Card className="relative z-0">
        <CardContent className="p-0">
          <motion.div
            key={`${typeFilter}-${searchQuery}`}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-x-auto"
          >
            <Table>
              <TableHeader>
                <TableRow>
                  <TableCell isHeader className="w-28">ID Laporan</TableCell>
                  <TableCell isHeader className="w-24">Jenis QC</TableCell>
                  <TableCell isHeader>Judul Laporan</TableCell>
                  <TableCell isHeader className="w-36">Lokasi</TableCell>
                  <TableCell isHeader className="w-36">QA Staff</TableCell>
                  <TableCell isHeader className="w-28">Tgl Submit</TableCell>
                  <TableCell isHeader className="w-28 text-center">Hasil Standar</TableCell>
                  <TableCell isHeader className="w-48 text-center">Aksi</TableCell>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={8} className="text-center py-16">
                      <div className="flex flex-col items-center gap-3 text-gray-400">
                        {pendingReports.length === 0 ? (
                          <>
                            <CheckCircle className="h-12 w-12 text-emerald-300" />
                            <p className="text-sm font-semibold text-emerald-700">Tidak ada laporan yang menunggu review</p>
                            <p className="text-xs text-gray-400">Semua laporan telah ditangani. Kerja bagus!</p>
                          </>
                        ) : (
                          <>
                            <FileText className="h-10 w-10 text-gray-200" />
                            <p className="text-sm font-medium">Tidak ada hasil yang cocok dengan pencarian</p>
                          </>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ) : (
                  filtered.map((rep) => {
                    const hasFailures = rep.checklistItems.some(c => c.result === 'FAIL');
                    return (
                      <TableRow key={rep.id} className="hover:bg-amber-50/30 group">
                        {/* ID */}
                        <TableCell>
                          <span className="font-mono text-xs font-bold text-[#006B5A]">{rep.id}</span>
                        </TableCell>
                        {/* Type */}
                        <TableCell>
                          <span className={`inline-flex items-center text-xs font-semibold px-2 py-0.5 rounded-full border ${
                            rep.type === 'material'
                              ? 'bg-blue-50 text-blue-700 border-blue-200/60'
                              : 'bg-violet-50 text-violet-700 border-violet-200/60'
                          }`}>
                            {rep.type === 'material' ? 'Material' : 'Pekerjaan'}
                          </span>
                        </TableCell>
                        {/* Title */}
                        <TableCell>
                          <p className="font-semibold text-gray-800 text-sm">{rep.title}</p>
                          <div className="flex items-center gap-3 mt-0.5">
                            <span className="text-xs text-gray-400">{rep.checklistItems.length} parameter</span>
                            {hasFailures && (
                              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-rose-600 bg-rose-50 px-1.5 py-0.5 rounded border border-rose-200">
                                <AlertCircle className="h-3 w-3" />
                                Ada kegagalan
                              </span>
                            )}
                          </div>
                        </TableCell>
                        {/* Location */}
                        <TableCell>
                          <span className="text-sm text-gray-600">{rep.locationName}</span>
                        </TableCell>
                        {/* Staff */}
                        <TableCell>
                          <p className="text-sm font-semibold text-gray-700">{rep.submittedBy}</p>
                          <p className="text-xs text-gray-400 font-mono">{rep.submittedByNik}</p>
                        </TableCell>
                        {/* Date */}
                        <TableCell>
                          <div className="flex items-center gap-1.5 text-xs text-gray-500">
                            <Clock className="h-3 w-3 text-gray-300" />
                            {new Date(rep.submittedAt).toLocaleDateString('id-ID', {
                              day: 'numeric', month: 'short', year: 'numeric'
                            })}
                          </div>
                        </TableCell>
                        {/* Standard Result */}
                        <TableCell className="text-center">
                          <StandardResultBadge result={rep.standardResult} />
                        </TableCell>
                        {/* Actions */}
                        <TableCell className="text-center">
                          <div className="flex items-center justify-center gap-1.5">
                            {/* Detail */}
                            <button
                              id={`detail-${rep.id}`}
                              onClick={() => navigate(`/laporan/${rep.id}`)}
                              className="p-1.5 rounded-lg text-gray-400 hover:text-[#006B5A] hover:bg-[#006B5A]/5 transition-all"
                              title="Lihat Detail"
                            >
                              <Eye className="h-4 w-4" />
                            </button>
                            {/* Approve */}
                            <button
                              id={`approve-${rep.id}`}
                              onClick={() => { setApproveTarget(rep); setApproveNote(''); }}
                              className="p-1.5 rounded-lg text-emerald-500 hover:text-emerald-700 hover:bg-emerald-50 transition-all"
                              title="Setujui"
                            >
                              <CheckCircle className="h-4 w-4" />
                            </button>
                            {/* Revision */}
                            <button
                              id={`revise-${rep.id}`}
                              onClick={() => { setRevisionTarget(rep); setRevisionNote(''); }}
                              className="p-1.5 rounded-lg text-rose-400 hover:text-rose-700 hover:bg-rose-50 transition-all"
                              title="Minta Perbaikan"
                            >
                              <RefreshCw className="h-4 w-4" />
                            </button>
                          </div>
                        </TableCell>
                      </TableRow>
                    );
                  })
                )}
              </TableBody>
            </Table>
          </motion.div>

          {filtered.length > 0 && (
            <div className="px-6 py-3 border-t border-gray-50 bg-gray-50/30">
              <p className="text-xs text-gray-400">
                Menampilkan <span className="font-semibold text-gray-600">{filtered.length}</span> dari{' '}
                <span className="font-semibold text-gray-600">{pendingReports.length}</span> laporan menunggu review
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* ── Approve Modal ────────────────────────── */}
      <Modal
        isOpen={approveTarget !== null}
        onClose={() => setApproveTarget(null)}
        title="Konfirmasi Persetujuan Laporan"
        footer={
          <div className="flex gap-2 w-full justify-end">
            <Button variant="outline" onClick={() => setApproveTarget(null)}>Batal</Button>
            <Button
              id="confirm-approve"
              variant="primary"
              className="bg-[#006B5A] hover:bg-[#005244]"
              onClick={handleApproveConfirm}
              disabled={approveTarget !== null && !approveTarget.checklistItems.every(i => i.result === 'PASS')}
            >
              <CheckCircle className="h-4 w-4 mr-1.5" />
              Ya, Setujui Laporan
            </Button>
          </div>
        }
      >
        {approveTarget && (
          <div className="space-y-4">
            {/* Summary */}
            <div className="p-3 bg-gray-50 rounded-xl border border-gray-200">
              <div className="text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wider">Laporan yang akan disetujui</div>
              <p className="font-bold text-gray-800 text-sm">{approveTarget.title}</p>
              <p className="text-xs text-gray-500 mt-0.5">
                {approveTarget.id} · {approveTarget.type === 'material' ? 'QC Material' : 'QC Pekerjaan'} · {approveTarget.locationName}
              </p>
              <p className="text-xs text-gray-500 mt-0.5">
                Oleh: {approveTarget.submittedBy} ({approveTarget.submittedByNik})
              </p>
            </div>

            {/* Warning if failures or needs review */}
            {approveTarget.checklistItems.some((c: ChecklistItem) => c.result === 'FAIL') && (
              <div className="flex items-start gap-2 p-3 bg-rose-50 border border-rose-200 rounded-xl text-xs text-rose-800 leading-relaxed">
                <AlertCircle className="h-4 w-4 text-rose-500 flex-shrink-0 mt-0.5" />
                <span>
                  <strong>Persetujuan Ditolak:</strong> Laporan ini memiliki parameter yang <strong>gagal</strong>. Laporan dengan parameter gagal tidak boleh disetujui.
                </span>
              </div>
            )}
            {approveTarget.checklistItems.some((c: ChecklistItem) => c.result === 'NEEDS_REVIEW') && (
              <div className="flex items-start gap-2 p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-800 leading-relaxed">
                <AlertCircle className="h-4 w-4 text-amber-500 flex-shrink-0 mt-0.5" />
                <span>
                  <strong>Persetujuan Ditolak:</strong> Masih ada parameter yang memerlukan <strong>review / evaluasi</strong>. Harap evaluasi setiap item terlebih dahulu.
                </span>
              </div>
            )}

            <p className="text-sm text-gray-600 leading-relaxed">
              Status laporan akan berubah menjadi <strong className="text-emerald-700">Disetujui</strong>. Tindakan ini akan dikunci dan tidak dapat diubah kembali.
            </p>

            {/* Optional note */}
            <div>
              <label htmlFor="approve-note" className="block text-xs font-semibold text-gray-700 mb-1.5">
                Catatan Approval <span className="text-gray-400 font-normal">(opsional)</span>
              </label>
              <textarea
                id="approve-note"
                rows={2}
                value={approveNote}
                onChange={(e) => setApproveNote(e.target.value)}
                placeholder="Contoh: Semua parameter terpenuhi, disetujui untuk dilanjutkan."
                className="w-full text-sm px-3 py-2.5 border border-gray-200 rounded-lg bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#006B5A]/20 focus:border-[#006B5A] placeholder-gray-300 resize-none transition-all"
              />
            </div>
          </div>
        )}
      </Modal>

      {/* ── Revision Modal ───────────────────────── */}
      <Modal
        isOpen={revisionTarget !== null}
        onClose={() => setRevisionTarget(null)}
        title="Minta Tindak Lanjut Laporan"
        footer={
          <div className="flex gap-2 w-full justify-end">
            <Button variant="outline" onClick={() => setRevisionTarget(null)}>Batal</Button>
            <Button
              id="confirm-revision"
              variant="danger"
              onClick={handleRevisionConfirm}
              disabled={
                !revisionNote.trim() ||
                (revisionTarget !== null && !revisionTarget.checklistItems.some(i => i.result === 'FAIL')) ||
                (revisionTarget !== null && revisionTarget.checklistItems.some(i => i.result === 'FAIL' && !i.adminNote?.trim()))
              }
            >
              <RefreshCw className="h-4 w-4 mr-1.5" />
              Kirim Instruksi Tindak Lanjut
            </Button>
          </div>
        }
      >
        {revisionTarget && (
          <div className="space-y-4">
            {/* Summary */}
            <div className="p-3 bg-gray-50 rounded-xl border border-gray-200">
              <div className="text-xs text-gray-400 mb-1 font-semibold uppercase tracking-wider">Laporan yang dikembalikan</div>
              <p className="font-bold text-gray-800 text-sm">{revisionTarget.title}</p>
              <p className="text-xs text-gray-500 mt-0.5">
                {revisionTarget.id} · {revisionTarget.locationName}
              </p>
              <p className="text-xs text-gray-500 mt-0.5">
                Oleh: {revisionTarget.submittedBy} ({revisionTarget.submittedByNik})
              </p>
            </div>

            <p className="text-sm text-gray-600 leading-relaxed">
              Status laporan akan berubah menjadi <strong className="text-rose-700">Perlu Tindak Lanjut</strong>.
              Staf lapangan akan menerima instruksi untuk menindaklanjuti data.
            </p>

            {/* Required note */}
            <div>
              <label htmlFor="revision-note" className="block text-xs font-semibold text-gray-700 mb-1.5">
                Catatan Instruksi Tindak Lanjut <span className="text-red-500">*</span>
              </label>
              <textarea
                id="revision-note"
                rows={3}
                value={revisionNote}
                onChange={(e) => setRevisionNote(e.target.value)}
                placeholder="Jelaskan bagian mana yang tidak memenuhi standar dan tindak lanjut apa yang perlu dilakukan oleh staf lapangan..."
                className={`w-full text-sm px-3 py-2.5 border rounded-lg bg-gray-50 focus:bg-white focus:outline-none focus:ring-2 placeholder-gray-300 resize-none transition-all ${
                  !revisionNote.trim()
                    ? 'border-gray-200 focus:ring-rose-400/20 focus:border-rose-400'
                    : 'border-gray-200 focus:ring-[#006B5A]/20 focus:border-[#006B5A]'
                }`}
                required
              />
              {revisionTarget !== null && !revisionTarget.checklistItems.some(i => i.result === 'FAIL') && (
                <p className="text-xs text-rose-500 mt-1 flex items-center gap-1">
                  <AlertCircle className="h-3 w-3" />
                  Minta Perbaikan ditolak: minimal harus ada satu parameter yang ditandai Gagal.
                </p>
              )}
              {revisionTarget !== null && revisionTarget.checklistItems.some(i => i.result === 'FAIL' && !i.adminNote?.trim()) && (
                <p className="text-xs text-rose-500 mt-1 flex items-center gap-1">
                  <AlertCircle className="h-3 w-3" />
                  Minta Perbaikan ditolak: semua parameter Gagal harus memiliki Catatan Admin.
                </p>
              )}
              {!revisionNote.trim() && (
                <p className="text-xs text-rose-500 mt-1 flex items-center gap-1">
                  <AlertCircle className="h-3 w-3" />
                  Catatan wajib diisi sebelum mengirim instruksi tindak lanjut.
                </p>
              )}
            </div>
          </div>
        )}
      </Modal>
    </PageTransition>
  );
};
