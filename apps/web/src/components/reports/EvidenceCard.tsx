import React from 'react';
import {
  Clock3,
  ExternalLink,
  Image as ImageIcon,
  MapPin,
} from 'lucide-react';
import type { QCReport } from '../../types/report';
import { evidenceCapturePresentation } from '../../utils/materialReportPresentation';

export interface EvidenceCardProps {
  objectPath: string;
  displayUrl: string;
  alt: string;
  generalInfo: QCReport['general_info'];
  onPreview: () => void;
}

export const EvidenceCard: React.FC<EvidenceCardProps> = ({
  objectPath,
  displayUrl,
  alt,
  generalInfo,
  onPreview,
}) => {
  const metadata = evidenceCapturePresentation(generalInfo, objectPath);

  return (
    <div className={metadata.hasMetadata
      ? 'flex min-w-[280px] max-w-md flex-col gap-2 rounded-lg border border-gray-200 bg-gray-50/60 p-2 sm:flex-row'
      : 'inline-flex w-fit rounded-lg border border-gray-200 bg-gray-50/60 p-2'}>
      <button
        type="button"
        onClick={onPreview}
        className={`relative h-20 flex-shrink-0 overflow-hidden rounded-md border border-gray-200 bg-white hover:border-[#006B5A] group ${metadata.hasMetadata ? 'w-full sm:w-20' : 'w-20'}`}
        aria-label={`Buka ${alt}`}
      >
        <ImageIcon className="absolute left-1/2 top-1/2 h-5 w-5 -translate-x-1/2 -translate-y-1/2 text-gray-400 group-hover:text-[#006B5A]" />
        {/^(?:https?:|\/|data:)/i.test(displayUrl) && (
          <img
            src={displayUrl}
            alt=""
            className="absolute inset-0 h-full w-full object-cover group-hover:scale-105 transition-transform duration-200"
            onError={event => {
              event.currentTarget.style.display = 'none';
            }}
          />
        )}
      </button>
      {metadata.hasMetadata && (
        <div className="min-w-0 flex-1 space-y-1 text-left text-[11px] leading-snug text-gray-600">
        <p className="flex items-start gap-1.5">
          <Clock3 className="mt-0.5 h-3 w-3 flex-shrink-0 text-gray-400" />
          <span><strong>Diambil:</strong> {metadata.capturedAt ?? '-'}</span>
        </p>
        <p className="flex items-start gap-1.5">
          <MapPin className="mt-0.5 h-3 w-3 flex-shrink-0 text-gray-400" />
          <span>
            <strong>Koordinat:</strong> {metadata.coordinates ?? '-'}
          </span>
        </p>
        <p>
          <strong>Akurasi:</strong> {metadata.accuracy ?? '-'}
        </p>
        {metadata.mapUrl ? (
          <a
            href={metadata.mapUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 font-semibold text-[#006B5A] hover:underline"
            onClick={e => e.stopPropagation()}
          >
            Buka di Google Maps
            <ExternalLink className="h-3 w-3" />
          </a>
        ) : metadata.locationUnavailable ? (
          <span className="text-[10px] italic text-gray-400">Lokasi tidak tersedia.</span>
        ) : (
          <span className="text-[10px] italic text-gray-400">Maps tidak tersedia</span>
        )}
        <p className="text-gray-400">
          <strong>Diterima server:</strong> {metadata.serverReceivedAt ?? '-'}
        </p>
        <p className="text-[10px] text-gray-400">
          Metadata perangkat bersifat informasi pendukung.
        </p>
        </div>
      )}
    </div>
  );
};

