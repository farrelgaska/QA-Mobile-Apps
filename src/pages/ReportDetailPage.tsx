import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useReports } from '../app/ReportsContext';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { PageTransition } from '../components/layout/PageTransition';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { ReportStatusBadge } from '../components/reports/ReportStatusBadge';
import { StandardResultBadge } from '../components/reports/StandardResultBadge';
import { ChecklistEvaluationTable } from '../components/reports/ChecklistEvaluationTable';
import { getReportStatusLabel } from '../utils/status';
import {
  Calendar,
  User,
  MapPin,
  ClipboardList,
  CheckCircle,
  AlertTriangle,
  RefreshCw,
  FileText,
  ImageIcon,
  ArrowLeft,
  Info,
  Loader2,
} from 'lucide-react';

export const ReportDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { getReport, approveReport, requestRevision, updateChecklistItem, loading: ctxLoading } = useReports();

  // Live report from context — re-evaluates on every render so UI updates instantly
  const report = id ? getReport(id) : undefined;

  // Modals state
  const [isApproveModalOpen, setIsApproveModalOpen] = useState(false);
  const [isRevisionModalOpen, setIsRevisionModalOpen] = useState(false);

  // Action loading states
  const [isApproving, setIsApproving] = useState(false);
  const [isRequestingRevision, setIsRequestingRevision] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  // Admin input fields
  const [adminFeedback, setAdminFeedback] = useState('');

  // Sync feedback with report adminNote when report changes
  useEffect(() => {
    if (report) {
      setAdminFeedback(report.adminNote || '');
    }
  }, [report?.adminNote]);

  const handleApprove = async () => {
    if (!report) return;
    setIsApproving(true);
    setActionError(null);
    try {
      await approveReport(report.id, adminFeedback || undefined);
      setIsApproveModalOpen(false);
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Gagal menyetujui laporan.');
      setIsApproveModalOpen(false);
    } finally {
      setIsApproving(false);
    }
  };

  const handleRequestRevision = async () => {
    if (!report) return;
    setIsRequestingRevision(true);
    setActionError(null);
    try {
      await requestRevision(report.id, adminFeedback || 'Harap lakukan perbaikan sesuai catatan yang dilampirkan.');
      setIsRevisionModalOpen(false);
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Gagal meminta tindak lanjut.');
      setIsRevisionModalOpen(false);
    } finally {
      setIsRequestingRevision(false);
    }
  };

  // ─── Loading (context still fetching initial data) ─────────────────────────
  if (ctxLoading && !report) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-400 gap-4">
        <Loader2 className="h-10 w-10 animate-spin text-[#006B5A]" />
        <p className="text-sm font-medium">Memuat laporan…</p>
      </div>
    );
  }

  // ─── Not Found ────────────────────────────────────────────────────────────
  if (!report) {
    return (
      <div className="flex flex-col items-center justify-center py-20 text-gray-500 gap-4">
        <div className="h-16 w-16 rounded-2xl bg-amber-50 border border-amber-200 flex items-center justify-center">
          <AlertTriangle className="h-8 w-8 text-amber-500" />
        </div>
        <div className="text-center">
          <p className="font-bold text-gray-700 text-lg">Laporan tidak ditemukan</p>
          <p className="text-sm text-gray-400 mt-1">
            Laporan dengan ID "<span className="font-mono font-semibold">{id}</span>" tidak ada dalam sistem.
          </p>
        </div>
        <Button variant="outline" onClick={() => navigate('/laporan')} className="mt-2">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Kembali ke Daftar Laporan
        </Button>
      </div>
    );
  }

  const hasFailures = report.checklistItems.some(i => i.result === 'FAIL');
  const hasPendingReviews = report.checklistItems.some(i => i.result === 'NEEDS_REVIEW');
  const isEditable = report.status === 'SUBMITTED';

  const canApprove = report.checklistItems.every(i => i.result === 'PASS');
  const canRequestRevision = hasFailures && report.checklistItems.filter(i => i.result === 'FAIL').every(i => i.adminNote?.trim());

  let approvalDisabledReason = '';
  if (hasFailures) {
    approvalDisabledReason = 'Persetujuan ditolak: Laporan ini memiliki parameter yang Gagal. Silakan minta perbaikan.';
  } else if (hasPendingReviews) {
    approvalDisabledReason = 'Persetujuan ditolak: Masih ada parameter yang belum dievaluasi (Review).';
  }

  let revisionDisabledReason = '';
  if (!hasFailures) {
    revisionDisabledReason = 'Minta Perbaikan ditolak: Harus ada minimal satu parameter yang ditandai Gagal.';
  } else if (report.checklistItems.some(i => i.result === 'FAIL' && !i.adminNote?.trim())) {
    revisionDisabledReason = 'Minta Perbaikan ditolak: Semua parameter yang Gagal harus memiliki Catatan Admin.';
  }

  // ─── Main render ──────────────────────────────────────────────────────────
  return (
    <PageTransition className="space-y-6 max-w-7xl mx-auto">

      {/* Action error banner */}
      {actionError && (
        <div className="flex items-start gap-3 p-3.5 rounded-xl border bg-rose-50 border-rose-200 text-rose-800 text-sm">
          <AlertTriangle className="h-4 w-4 text-rose-500 flex-shrink-0 mt-0.5" />
          <span>{actionError}</span>
          <button onClick={() => setActionError(null)} className="ml-auto text-rose-400 hover:text-rose-600 text-xs font-bold">×</button>
        </div>
      )}

      {/* ── Top Nav Bar ─────────────────────── */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <Button variant="outline" onClick={() => navigate('/laporan')} className="hover:bg-gray-50">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Kembali ke Daftar
        </Button>
        <div className="flex items-center gap-2 flex-wrap">
          <Badge color="gray" className="text-xs font-mono font-bold tracking-wide">
            {report.id}
          </Badge>
          <span className="text-gray-300">|</span>
          <ReportStatusBadge status={report.status} />
          <StandardResultBadge result={report.standardResult} />
        </div>
      </div>

      {/* ── Status Banner ──────────────────── */}
      {report.status === 'SUBMITTED' && (
        <div className={`flex items-start gap-4 p-4 rounded-xl border shadow-sm ${
          hasFailures
            ? 'bg-rose-50 border-rose-200 text-rose-800'
            : hasPendingReviews
              ? 'bg-amber-50 border-amber-200 text-amber-800'
              : 'bg-emerald-50 border-emerald-200 text-emerald-800'
        }`}>
          <div className="flex-shrink-0 mt-0.5">
            {hasFailures
              ? <AlertTriangle className="h-5 w-5 text-rose-500" />
              : hasPendingReviews
                ? <AlertTriangle className="h-5 w-5 text-amber-500" />
                : <CheckCircle className="h-5 w-5 text-emerald-600" />
            }
          </div>
          <div>
            <p className="font-bold text-sm">
              {hasFailures
                ? 'Terdeteksi kegagalan pada parameter QC'
                : hasPendingReviews
                  ? 'Beberapa parameter memerlukan tinjauan manual'
                  : 'Semua parameter terkonfirmasi Lulus Standar'}
            </p>
            <p className="text-xs mt-1 opacity-85 leading-relaxed">
              {hasFailures
                ? 'Sistem mendeteksi minimal satu parameter gagal. Direkomendasikan untuk meminta perbaikan atau mengubah hasil evaluasi.'
                : hasPendingReviews
                  ? 'Silakan periksa foto bukti dan ubah hasil evaluasi tiap parameter sebelum melakukan approval.'
                  : 'Anda dapat langsung menyetujui laporan ini.'}
            </p>
          </div>
        </div>
      )}

      {report.status === 'APPROVED' && (
        <div className="flex items-start gap-3 p-4 rounded-xl border bg-emerald-50 border-emerald-200 text-emerald-800">
          <CheckCircle className="h-5 w-5 text-emerald-600 flex-shrink-0 mt-0.5" />
          <div>
            <p className="font-bold text-sm">Laporan ini telah disetujui</p>
            {report.adminNote && <p className="text-xs mt-0.5 opacity-80">{report.adminNote}</p>}
          </div>
        </div>
      )}
      {report.status === 'NEEDS_FOLLOW_UP' && (
        <div className="flex items-start gap-3 p-4 rounded-xl border bg-rose-50 border-rose-200 text-rose-800">
          <RefreshCw className="h-5 w-5 text-rose-600 flex-shrink-0 mt-0.5" />
          <div>
            <p className="font-bold text-sm">Laporan ini diminta tindak lanjut</p>
            {report.adminNote && <p className="text-xs mt-0.5 opacity-80">{report.adminNote}</p>}
          </div>
        </div>
      )}

      {/* ── Main Grid Layout ─────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* LEFT: Metadata + Photos */}
        <div className="lg:col-span-1 space-y-5">
          <Card title="Informasi Laporan">
            <CardContent className="space-y-4 pt-3">
              {[
                { icon: <FileText className="h-4 w-4" />, label: 'Jenis Inspeksi', value: `QC ${report.type === 'material' ? 'Material' : 'Pekerjaan'}` },
                { icon: <ClipboardList className="h-4 w-4" />, label: 'Nama Item / Aktivitas', value: report.title },
                { icon: <MapPin className="h-4 w-4" />, label: 'Lokasi Konstruksi', value: report.locationName },
                { icon: <User className="h-4 w-4" />, label: 'QA Staff Pengirim', value: `${report.submittedBy} (${report.submittedByNik})` },
                {
                  icon: <Calendar className="h-4 w-4" />,
                  label: 'Waktu Pengiriman',
                  value: new Date(report.submittedAt).toLocaleString('id-ID', { dateStyle: 'medium', timeStyle: 'short' })
                },
              ].map((row, i) => (
                <div key={i} className="flex items-start gap-3">
                  <div className="flex-shrink-0 h-8 w-8 rounded-lg bg-gray-50 border border-gray-100 flex items-center justify-center text-gray-400">
                    {row.icon}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-[11px] text-gray-400 font-semibold uppercase tracking-wider">{row.label}</div>
                    <div className="text-sm font-semibold text-gray-800 leading-snug mt-0.5 break-words">{row.value}</div>
                  </div>
                </div>
              ))}

              {/* Parameter summary */}
              <div className="pt-2 border-t border-gray-100">
                <div className="text-[11px] text-gray-400 font-semibold uppercase tracking-wider mb-2">Ringkasan Parameter</div>
                <div className="grid grid-cols-3 gap-2">
                  <div className="text-center p-2 bg-emerald-50 rounded-lg border border-emerald-100">
                    <div className="text-lg font-extrabold text-emerald-700">
                      {report.checklistItems.filter(c => c.result === 'PASS').length}
                    </div>
                    <div className="text-[10px] text-emerald-600 font-semibold mt-0.5">Lulus</div>
                  </div>
                  <div className="text-center p-2 bg-rose-50 rounded-lg border border-rose-100">
                    <div className="text-lg font-extrabold text-rose-700">
                      {report.checklistItems.filter(c => c.result === 'FAIL').length}
                    </div>
                    <div className="text-[10px] text-rose-600 font-semibold mt-0.5">Gagal</div>
                  </div>
                  <div className="text-center p-2 bg-amber-50 rounded-lg border border-amber-100">
                    <div className="text-lg font-extrabold text-amber-700">
                      {report.checklistItems.filter(c => c.result === 'NEEDS_REVIEW').length}
                    </div>
                    <div className="text-[10px] text-amber-600 font-semibold mt-0.5">Review</div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Photo Gallery */}
          <Card title="Galeri Foto Lapangan">
            <CardContent className="pt-3">
              {report.photos && report.photos.length > 0 ? (
                <div className="grid grid-cols-2 gap-2">
                  {report.photos.map((url, i) => (
                    <a
                      key={i}
                      href={url}
                      target="_blank"
                      rel="noreferrer"
                      className="group relative aspect-video rounded-lg overflow-hidden border border-gray-100 bg-gray-50 hover:border-[#006B5A] hover:shadow-md transition-all duration-200"
                    >
                      <img
                        src={url}
                        alt={`Bukti lapangan ${i + 1}`}
                        className="h-full w-full object-cover group-hover:scale-105 transition-transform duration-300"
                      />
                      <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors duration-200 flex items-center justify-center">
                        <span className="opacity-0 group-hover:opacity-100 text-white text-[10px] font-bold bg-black/50 px-2 py-0.5 rounded transition-opacity">
                          Buka
                        </span>
                      </div>
                    </a>
                  ))}
                </div>
              ) : (
                <div className="flex flex-col items-center justify-center py-8 text-gray-300 gap-2">
                  <ImageIcon className="h-10 w-10" />
                  <p className="text-xs text-gray-400 italic">Tidak ada foto bukti lapangan</p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* RIGHT: Checklist + Decision */}
        <div className="lg:col-span-2 space-y-5">
          <Card title="Evaluasi Parameter Standar QC">
            <CardContent className="pt-3">
              {isEditable && (
                <div className="flex items-start gap-2 p-3 mb-4 bg-blue-50/60 border border-blue-200/60 rounded-xl text-xs text-blue-700 leading-relaxed">
                  <Info className="h-4 w-4 flex-shrink-0 mt-0.5 text-blue-500" />
                  <span>
                    Klik tombol <strong>Lulus</strong>, <strong>Gagal</strong>, atau <strong>Review</strong> pada setiap baris untuk memperbarui hasil evaluasi parameter.
                  </span>
                </div>
              )}
              <ChecklistEvaluationTable
                items={report.checklistItems}
                isEditable={isEditable}
                onUpdateItem={(itemId, result, note) =>
                  updateChecklistItem(report.id, itemId, result, note)
                }
              />
            </CardContent>
          </Card>

          {/* Decision Card */}
          <Card title="Keputusan Admin">
            <CardContent className="pt-3">
              {!isEditable ? (
                <div className="space-y-3">
                  <div className="p-4 rounded-xl bg-gray-50 border border-gray-200/70">
                    <div className="text-[11px] text-gray-400 font-semibold uppercase tracking-wider mb-1.5">Catatan Admin</div>
                    <p className="text-sm text-gray-700 leading-relaxed italic">
                      "{report.adminNote || 'Tidak ada catatan tambahan.'}"
                    </p>
                  </div>
                  <p className="text-xs text-gray-400">
                    Status laporan telah ditetapkan sebagai <strong>{getReportStatusLabel(report.status)}</strong>.
                  </p>
                </div>
              ) : (
                <div className="space-y-5">
                  {approvalDisabledReason && (
                    <div className="p-3.5 bg-rose-50 border border-rose-150 text-rose-800 text-xs rounded-xl flex items-start gap-2 leading-relaxed">
                      <AlertTriangle className="h-4 w-4 text-rose-500 flex-shrink-0 mt-0.5" />
                      <span>{approvalDisabledReason}</span>
                    </div>
                  )}
                  {revisionDisabledReason && (
                    <div className="p-3.5 bg-amber-50 border border-amber-150 text-amber-850 text-xs rounded-xl flex items-start gap-2 leading-relaxed">
                      <Info className="h-4 w-4 text-amber-500 flex-shrink-0 mt-0.5" />
                      <span>{revisionDisabledReason}</span>
                    </div>
                  )}

                  <div>
                    <label htmlFor="admin-feedback" className="block text-xs font-bold text-gray-700 mb-1.5">
                      Catatan Evaluasi / Instruksi Revisi{' '}
                      <span className="text-gray-400 font-normal">(opsional untuk approval, wajib untuk perbaikan)</span>
                    </label>
                    <textarea
                      id="admin-feedback"
                      rows={3}
                      value={adminFeedback}
                      onChange={(e) => setAdminFeedback(e.target.value)}
                      placeholder="Masukkan catatan spesifik mengenai parameter atau instruksi perbaikan untuk staf lapangan..."
                      className="w-full text-sm px-4 py-3 border border-gray-200 rounded-xl bg-gray-50/40 focus:bg-white focus:outline-none focus:ring-2 focus:ring-[#006B5A]/20 focus:border-[#006B5A] placeholder-gray-300 transition-all leading-relaxed resize-none"
                    />
                  </div>
                  <div className="flex items-center gap-3">
                    <Button
                      id="btn-request-revision"
                      variant="danger"
                      onClick={() => setIsRevisionModalOpen(true)}
                      className="flex-1 shadow-sm"
                      disabled={!canRequestRevision || isApproving || isRequestingRevision}
                    >
                      {isRequestingRevision
                        ? <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        : <RefreshCw className="mr-2 h-4 w-4" />}
                      Minta Perbaikan
                    </Button>
                    <Button
                      id="btn-approve"
                      variant="primary"
                      onClick={() => setIsApproveModalOpen(true)}
                      className="flex-1 bg-[#006B5A] hover:bg-[#005244] shadow-sm shadow-[#006B5A]/20"
                      disabled={!canApprove || isApproving || isRequestingRevision}
                    >
                      {isApproving
                        ? <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        : <CheckCircle className="mr-2 h-4 w-4" />}
                      Setujui Laporan
                    </Button>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      {/* ── Approve Modal ─────────────────────── */}
      <Modal
        isOpen={isApproveModalOpen}
        onClose={() => setIsApproveModalOpen(false)}
        title="Konfirmasi Persetujuan Laporan"
        footer={
          <div className="flex gap-2 w-full justify-end">
            <Button variant="outline" onClick={() => setIsApproveModalOpen(false)}>Batal</Button>
            <Button
              id="confirm-approve-btn"
              variant="primary"
              onClick={handleApprove}
              disabled={isApproving}
              className="bg-[#006B5A] hover:bg-[#005244]"
            >
              {isApproving
                ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" />Menyimpan…</>
                : 'Ya, Setujui Sekarang'}
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <p className="text-sm text-gray-600 leading-relaxed">
            Apakah Anda yakin ingin menyetujui laporan <strong className="text-gray-900">{report.id}</strong>?{' '}
            Status laporan akan berubah menjadi <strong className="text-emerald-700">Disetujui</strong> dan dikunci.
          </p>
          {adminFeedback && (
            <div className="p-3 bg-gray-50 rounded-lg border border-gray-200 text-xs text-gray-500 leading-relaxed">
              <span className="font-bold text-gray-700">Catatan: </span>{adminFeedback}
            </div>
          )}
        </div>
      </Modal>

      {/* ── Revision Modal ────────────────────── */}
      <Modal
        isOpen={isRevisionModalOpen}
        onClose={() => setIsRevisionModalOpen(false)}
        title="Minta Tindak Lanjut Laporan"
        footer={
          <div className="flex gap-2 w-full justify-end">
            <Button variant="outline" onClick={() => setIsRevisionModalOpen(false)}>Batal</Button>
            <Button
              id="confirm-revision-btn"
              variant="danger"
              onClick={handleRequestRevision}
              disabled={!adminFeedback.trim()}
            >
              Kirim Instruksi Tindak Lanjut
            </Button>
          </div>
        }
      >
        <div className="space-y-4">
          <p className="text-sm text-gray-600 leading-relaxed">
            Laporan <strong className="text-gray-900">{report.id}</strong> akan dikembalikan ke status{' '}
            <strong className="text-rose-700">Perlu Tindak Lanjut</strong>.
          </p>
          <div>
            <label htmlFor="revision-feedback" className="block text-xs font-bold text-gray-700 mb-1.5">
              Catatan Instruksi Tindak Lanjut <span className="text-red-500">*</span>
            </label>
            <textarea
              id="revision-feedback"
              rows={3}
              value={adminFeedback}
              onChange={(e) => setAdminFeedback(e.target.value)}
              placeholder="Jelaskan bagian mana yang gagal dan perlu ditindaklanjuti..."
              className="w-full text-sm px-3 py-2.5 border border-gray-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-rose-400 focus:border-rose-400 placeholder-gray-300 resize-none"
              required
            />
            {!adminFeedback.trim() && (
              <p className="text-xs text-rose-500 mt-1">Catatan wajib diisi.</p>
            )}
          </div>
        </div>
      </Modal>
    </PageTransition>
  );
};
