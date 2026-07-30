import React, { useEffect, useState } from 'react';
import {
  AlertCircle,
  AlertTriangle,
  Check,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  Clock3,
  ExternalLink,
  Image as ImageIcon,
  MapPin,
  OctagonX,
  X,
} from 'lucide-react';
import type {
  ChecklistResult,
  ParameterEvaluationStatus,
  QCReport,
  SampleChecklistAnswer,
} from '../../types/report';
import {
  evidenceCapturePresentation,
  hasCurrentSampleOutOfStandard,
  isPersistedStopDecision,
  PARAMETER_EVALUATION_LABELS,
  parameterAdminNoteState,
  persistedSampleEvaluationStatuses,
  persistedSamplePage,
  persistedSamplingFailedNumbers,
  sortedPersistedSamples,
} from '../../utils/materialReportPresentation';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';
import { Card, CardContent } from '../ui/Card';
import { ImagePreviewModal } from './ImagePreviewModal';

interface MaterialSampleEvaluationProps {
  report: QCReport;
  isEditable: boolean;
  onUpdateSampleAnswer: (
    sampleId: string,
    checklistItemId: string,
    result: ChecklistResult,
    note: string
  ) => void;
}

interface EvidencePhotoProps {
  objectPath: string;
  displayUrl: string;
  alt: string;
  generalInfo: QCReport['general_info'];
  onPreview: () => void;
}

const EvidencePhoto: React.FC<EvidencePhotoProps> = ({
  objectPath,
  displayUrl,
  alt,
  generalInfo,
  onPreview,
}) => {
  const metadata = evidenceCapturePresentation(generalInfo, objectPath);
  const containerClassName = metadata.hasMetadata
    ? 'flex min-w-[280px] max-w-md flex-col gap-2 rounded-lg border border-gray-200 bg-gray-50/60 p-2 sm:flex-row'
    : 'inline-flex w-fit rounded-lg border border-gray-200 bg-gray-50/60 p-2';
  const photoButtonClassName = metadata.hasMetadata
    ? 'relative h-20 w-full flex-shrink-0 overflow-hidden rounded-md border border-gray-200 bg-white hover:border-[#006B5A] sm:w-20'
    : 'relative h-20 w-20 flex-shrink-0 overflow-hidden rounded-md border border-gray-200 bg-white hover:border-[#006B5A]';

  return (
    <div className={containerClassName}>
      <button
        type="button"
        onClick={onPreview}
        className={photoButtonClassName}
        aria-label={`Buka ${alt}`}
      >
        <ImageIcon className="absolute left-1/2 top-1/2 h-5 w-5 -translate-x-1/2 -translate-y-1/2 text-gray-400" />
        {/^(?:https?:|\/|data:)/i.test(displayUrl) && (
          <img
            src={displayUrl}
            alt=""
            className="absolute inset-0 h-full w-full object-cover"
            onError={event => {
              event.currentTarget.style.display = 'none';
            }}
          />
        )}
      </button>
      {metadata.hasMetadata && (
        <div className="min-w-0 flex-1 space-y-1 text-[11px] leading-snug text-gray-600">
          <>
            {metadata.capturedAt && (
              <p className="flex items-start gap-1.5">
                <Clock3 className="mt-0.5 h-3 w-3 flex-shrink-0 text-gray-400" />
                <span><strong>Diambil:</strong> {metadata.capturedAt}</span>
              </p>
            )}
            {metadata.locationLabel && (
              <p className="flex items-start gap-1.5">
                <MapPin className="mt-0.5 h-3 w-3 flex-shrink-0 text-gray-400" />
                <span>{metadata.locationLabel}</span>
              </p>
            )}
            {metadata.coordinates && (
              <p><strong>Koordinat:</strong> {metadata.coordinates}</p>
            )}
            {metadata.accuracy && (
              <p><strong>Akurasi:</strong> {metadata.accuracy}</p>
            )}
            {metadata.locationUnavailable && (
              <p className="italic text-amber-700">Lokasi tidak tersedia.</p>
            )}
            {metadata.mapUrl && (
              <a
                href={metadata.mapUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-1 font-semibold text-[#006B5A] hover:underline"
              >
                Buka di Google Maps
                <ExternalLink className="h-3 w-3" />
              </a>
            )}
            {metadata.serverReceivedAt && (
              <p className="text-gray-400">
                <strong>Diterima server:</strong> {metadata.serverReceivedAt}
              </p>
            )}
            <p className="text-[10px] text-gray-400">
              Metadata perangkat bersifat informasi pendukung.
            </p>
          </>
        </div>
      )}
    </div>
  );
};

const evaluationColor = (
  status: ParameterEvaluationStatus
): 'green' | 'red' | 'gray' => {
  if (status === 'WITHIN_STANDARD') return 'green';
  if (status === 'OUT_OF_STANDARD') return 'red';
  return 'gray';
};

const adminDecisionLabel = (result: ChecklistResult): string => {
  if (result === 'PASS') return 'Lulus';
  if (result === 'FAIL') return 'Gagal';
  return 'Review';
};

const adminDecisionColor = (
  result: ChecklistResult
): 'green' | 'red' | 'yellow' => {
  if (result === 'PASS') return 'green';
  if (result === 'FAIL') return 'red';
  return 'yellow';
};

const displayActualValue = (answer: SampleChecklistAnswer): string => {
  if (answer.actual_value === null || answer.actual_value === '') return 'Kosong';
  return `${String(answer.actual_value)}${answer.unit ? ` ${answer.unit}` : ''}`;
};

const displayPersistedBounds = (answer: SampleChecklistAnswer): string | null => {
  const values = [
    answer.standard_value !== null ? `Nilai acuan ${answer.standard_value}` : null,
    answer.minimum_value !== null ? `Min ${answer.minimum_value}` : null,
    answer.maximum_value !== null ? `Maks ${answer.maximum_value}` : null,
    answer.lower_tolerance !== null ? `Toleransi bawah ${answer.lower_tolerance}` : null,
    answer.upper_tolerance !== null ? `Toleransi atas ${answer.upper_tolerance}` : null,
  ].filter(Boolean);
  return values.length > 0 ? values.join(' · ') : null;
};

export const MaterialSampleEvaluation: React.FC<MaterialSampleEvaluationProps> = ({
  report,
  isEditable,
  onUpdateSampleAnswer,
}) => {
  const samples = sortedPersistedSamples(report.samples);
  const [selectedSampleId, setSelectedSampleId] = useState<string | undefined>(
    samples[0]?.id
  );
  const [previewImage, setPreviewImage] = useState<{
    url: string;
    alt: string;
  } | null>(null);

  useEffect(() => {
    if (samples.length === 0) {
      setSelectedSampleId(undefined);
    } else if (!samples.some(sample => sample.id === selectedSampleId)) {
      setSelectedSampleId(samples[0].id);
    }
  }, [samples, selectedSampleId]);

  if (report.type !== 'material' || samples.length === 0) return null;

  const page = persistedSamplePage(samples, selectedSampleId);
  const sample = page.currentSample;
  if (!sample) return null;
  const displayPhotoUrl = (objectPath: string) =>
    report.evidenceDisplayUrls?.[objectPath] ?? objectPath;

  const sampleStatuses = persistedSampleEvaluationStatuses(report.general_info);
  const sampleStatus = sampleStatuses[sample.id];
  const failedSampleNumbers = persistedSamplingFailedNumbers(report.general_info);
  const hasOutOfStandard = hasCurrentSampleOutOfStandard(sample, sampleStatus);
  const isStop = isPersistedStopDecision(report);
  const hasVisibleParameterPhotoMetadata = sample.checklist_answers.some(
    answer => answer.photo_paths.some(
      objectPath =>
        evidenceCapturePresentation(report.general_info, objectPath).hasMetadata
    )
  );
  const evidenceColumnClassName = hasVisibleParameterPhotoMetadata
    ? 'w-[380px] min-w-[380px]'
    : 'w-[112px] min-w-[112px]';

  return (
    <>
      {isStop && (
        <Card title="Keputusan Sampling">
          <CardContent className="space-y-3 pt-3">
            <div className="flex items-center gap-2">
              <OctagonX className="h-5 w-5 text-rose-600" />
              <Badge color="red" className="font-bold">STOP</Badge>
            </div>
            <div>
              <p className="text-[11px] font-semibold uppercase tracking-wider text-gray-400">
                Alasan penghentian
              </p>
              <p className="mt-1 text-sm font-semibold text-gray-800">
                {report.general_info?.qcSamplingStopReason || 'Tidak ada alasan tersimpan.'}
              </p>
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-wider text-gray-400">
                  Nomor sampel gagal
                </p>
                <p className="mt-1 text-sm font-semibold text-gray-800">
                  {failedSampleNumbers.length > 0
                    ? failedSampleNumbers.join(', ')
                    : 'Tidak tersedia'}
                </p>
              </div>
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-wider text-gray-400">
                  Permintaan review
                </p>
                <p className="mt-1 text-sm font-semibold text-gray-800">
                  {report.review_requested ? 'Review diminta' : 'Review belum diminta'}
                </p>
                {report.review_requested_at && (
                  <p className="mt-0.5 text-xs text-gray-500">
                    {new Date(report.review_requested_at).toLocaleString('id-ID')}
                  </p>
                )}
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      <Card title="Evaluasi Multi-Sampel Tersimpan">
        <CardContent className="space-y-4 pt-3">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <Button
              variant="outline"
              onClick={() => page.previousSampleId &&
                setSelectedSampleId(page.previousSampleId)}
              disabled={!page.previousSampleId}
            >
              <ChevronLeft className="mr-1 h-4 w-4" />
              Sebelumnya
            </Button>
            <div className="text-center">
              <p className="text-sm font-bold text-gray-800">{page.indicator}</p>
              <p className="mt-0.5 text-[11px] text-gray-400">
                Data sampel telah dimuat bersama laporan
              </p>
            </div>
            <Button
              variant="outline"
              onClick={() => page.nextSampleId &&
                setSelectedSampleId(page.nextSampleId)}
              disabled={!page.nextSampleId}
            >
              Selanjutnya
              <ChevronRight className="ml-1 h-4 w-4" />
            </Button>
          </div>

          {hasOutOfStandard && (
            <div className="flex items-start gap-3 rounded-xl border border-rose-200 bg-rose-50 p-4 text-rose-800">
              <AlertTriangle className="mt-0.5 h-5 w-5 flex-shrink-0 text-rose-600" />
              <div>
                <p className="text-sm font-bold">
                  Sampel ini memiliki hasil inspeksi tidak sesuai standar
                </p>
                <p className="mt-1 text-xs leading-relaxed">
                  Status Standar berasal dari inspeksi Mobile dan bersifat informasional.
                  Keputusan Admin tetap ditentukan secara terpisah.
                </p>
              </div>
            </div>
          )}

          <section className="overflow-hidden rounded-xl border border-gray-200 bg-white">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-100 bg-gray-50 px-4 py-3">
              <div className="flex items-center gap-2">
                <ClipboardList className="h-4 w-4 text-[#006B5A]" />
                <h3 className="text-sm font-bold text-gray-800">
                  Sampel {sample.sample_number}
                </h3>
                <span className="font-mono text-[11px] text-gray-400">{sample.id}</span>
              </div>
              <div className="flex items-center gap-2">
                <Badge color="gray">{sample.inspection_status}</Badge>
                {sampleStatus && (
                  <Badge color={evaluationColor(sampleStatus)}>
                    {PARAMETER_EVALUATION_LABELS[sampleStatus]}
                  </Badge>
                )}
              </div>
            </div>

            {sample.photo_paths.length > 0 && (
              <div className="border-b border-gray-100 px-4 py-3">
                <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-gray-400">
                  Bukti Foto Sampel
                </p>
                <div className="flex flex-wrap items-start gap-2">
                  {sample.photo_paths.map((objectPath, index) => {
                    const displayUrl = displayPhotoUrl(objectPath);
                    const alt =
                      `foto sampel ${sample.sample_number} nomor ${index + 1}`;
                    return (
                      <EvidencePhoto
                        key={`${objectPath}:${index}`}
                        objectPath={objectPath}
                        displayUrl={displayUrl}
                        alt={alt}
                        generalInfo={report.general_info}
                        onPreview={() => setPreviewImage({ url: displayUrl, alt })}
                      />
                    );
                  })}
                </div>
              </div>
            )}

            <div className="overflow-x-auto">
              <table
                className={`w-full table-fixed text-left text-sm ${
                  hasVisibleParameterPhotoMetadata
                    ? 'min-w-[1620px]'
                    : 'min-w-[1360px]'
                }`}
              >
                <colgroup>
                  <col className="w-[180px]" />
                  <col className="w-[220px]" />
                  <col className="w-[130px]" />
                  <col className="w-[150px]" />
                  <col className="w-[240px]" />
                  <col className={evidenceColumnClassName} />
                  <col className="w-[190px]" />
                  <col className="w-[260px]" />
                </colgroup>
                <thead className="border-b border-gray-100 bg-white text-[11px] uppercase tracking-wider text-gray-400">
                  <tr>
                    <th className="px-4 py-3">Parameter</th>
                    <th className="px-4 py-3">Standar Tersimpan</th>
                    <th className="px-4 py-3">Nilai Aktual</th>
                    <th className="px-4 py-3">Status Standar</th>
                    <th className="px-4 py-3">Keputusan Admin</th>
                    <th className="px-3 py-3">Bukti Foto</th>
                    <th className="px-4 py-3">Catatan Staff</th>
                    <th className="px-4 py-3">Catatan Admin</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {sample.checklist_answers.map(answer => {
                    const adminItem = report.checklistItems.find(
                      item => item.id === answer.checklist_item_id
                    );
                    const parameterName =
                      adminItem?.name || answer.checklist_item_id;
                    const adminResult =
                      answer.admin_evaluation ?? 'NEEDS_REVIEW';
                    const adminNote = answer.admin_note ?? '';
                    const adminNoteState = parameterAdminNoteState(
                      adminResult,
                      adminNote
                    );
                    return (
                      <tr key={answer.checklist_item_id}>
                        <td className="px-4 py-3 font-semibold text-gray-800">
                          {parameterName}
                        </td>
                        <td className="px-4 py-3 text-gray-600">
                          <p>{answer.standard_text || '-'}</p>
                          {displayPersistedBounds(answer) && (
                            <p className="mt-1 text-[11px] text-gray-400">
                              {displayPersistedBounds(answer)}
                            </p>
                          )}
                        </td>
                        <td className="px-4 py-3 font-semibold text-gray-800">
                          {displayActualValue(answer)}
                        </td>
                        <td className="px-4 py-3">
                          <Badge color={evaluationColor(answer.evaluation_status)}>
                            {PARAMETER_EVALUATION_LABELS[answer.evaluation_status]}
                          </Badge>
                        </td>
                        <td className="px-4 py-3">
                          {isEditable ? (
                            <div className="flex items-center gap-1">
                              {([
                                ['PASS', 'Lulus', Check],
                                ['FAIL', 'Gagal', X],
                                ['NEEDS_REVIEW', 'Review', AlertCircle],
                              ] as const).map(([result, label, Icon]) => (
                                <button
                                  key={result}
                                  type="button"
                                  onClick={() => onUpdateSampleAnswer(
                                    sample.id,
                                    answer.checklist_item_id,
                                    result,
                                    adminNote
                                  )}
                                  className={`flex items-center gap-1 rounded-lg border px-2 py-1.5 text-xs font-semibold transition-colors ${
                                    adminResult === result
                                      ? result === 'PASS'
                                        ? 'border-emerald-300 bg-emerald-50 text-emerald-700'
                                        : result === 'FAIL'
                                          ? 'border-rose-300 bg-rose-50 text-rose-700'
                                          : 'border-amber-300 bg-amber-50 text-amber-700'
                                      : 'border-gray-200 bg-white text-gray-400 hover:bg-gray-50'
                                  }`}
                                >
                                  <Icon className="h-3.5 w-3.5" />
                                  {label}
                                </button>
                              ))}
                            </div>
                          ) : (
                            <Badge color={adminDecisionColor(adminResult)}>
                              {adminDecisionLabel(adminResult)}
                            </Badge>
                          )}
                        </td>
                        <td
                          className={`${evidenceColumnClassName} px-3 py-3 align-top`}
                        >
                          {answer.photo_paths.length > 0 ? (
                            <div className="space-y-2">
                              {answer.photo_paths.map((objectPath, index) => {
                                const displayUrl = displayPhotoUrl(objectPath);
                                const alt =
                                  `foto sampel ${sample.sample_number} ${parameterName} nomor ${index + 1}`;
                                return (
                                  <EvidencePhoto
                                    key={`${objectPath}:${index}`}
                                    objectPath={objectPath}
                                    displayUrl={displayUrl}
                                    alt={alt}
                                    generalInfo={report.general_info}
                                    onPreview={() => setPreviewImage({
                                      url: displayUrl,
                                      alt,
                                    })}
                                  />
                                );
                              })}
                            </div>
                          ) : (
                            <span className="text-xs italic text-gray-400">Tidak ada foto</span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-gray-600">
                          {answer.note || '-'}
                        </td>
                        <td className="min-w-[250px] px-4 py-3 align-top">
                          {isEditable ? (
                            <div className="space-y-1.5">
                              <textarea
                                rows={2}
                                value={adminNote}
                                onChange={event => onUpdateSampleAnswer(
                                  sample.id,
                                  answer.checklist_item_id,
                                  adminResult,
                                  event.target.value
                                )}
                                required={adminNoteState.required}
                                aria-required={adminNoteState.required}
                                aria-invalid={adminNoteState.missing}
                                aria-label={`Catatan Admin untuk ${parameterName} pada sampel ${sample.sample_number}`}
                                placeholder={
                                  adminNoteState.required
                                    ? 'Wajib diisi untuk parameter Gagal'
                                    : 'Tambahkan catatan Admin'
                                }
                                className={`w-full resize-y rounded-lg border px-3 py-2 text-xs leading-relaxed outline-none transition-colors ${
                                  adminNoteState.missing
                                    ? 'border-rose-300 bg-rose-50 text-rose-800 focus:border-rose-500 focus:ring-2 focus:ring-rose-100'
                                    : 'border-gray-200 bg-white text-gray-700 focus:border-[#006B5A] focus:ring-2 focus:ring-[#006B5A]/10'
                                }`}
                              />
                              {adminNoteState.message && (
                                <p
                                  role="alert"
                                  className="text-[11px] font-semibold text-rose-600"
                                >
                                  {adminNoteState.message}
                                </p>
                              )}
                            </div>
                          ) : adminNote.trim() ? (
                            <p className="whitespace-pre-wrap text-xs text-gray-700">
                              {adminNote}
                            </p>
                          ) : (
                            <span className="text-xs italic text-gray-400">-</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            <div className="grid gap-2 border-t border-gray-100 px-4 py-3 text-xs text-gray-500 sm:grid-cols-3">
              <p><strong>Catatan sampel:</strong> {sample.notes || '-'}</p>
              <p><strong>Dibuat:</strong> {new Date(sample.created_at).toLocaleString('id-ID')}</p>
              <p><strong>Diperbarui:</strong> {new Date(sample.updated_at).toLocaleString('id-ID')}</p>
            </div>
          </section>
        </CardContent>
      </Card>

      <ImagePreviewModal
        imageUrl={previewImage?.url ?? null}
        alt={previewImage?.alt ?? 'Bukti parameter sampel'}
        onClose={() => setPreviewImage(null)}
      />
    </>
  );
};
