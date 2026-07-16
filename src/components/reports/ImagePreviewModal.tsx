import React, { useEffect } from 'react';
import { X } from 'lucide-react';

export interface ImagePreviewModalProps {
  imageUrl: string | null;
  alt: string;
  onClose: () => void;
}

export const ImagePreviewModal: React.FC<ImagePreviewModalProps> = ({
  imageUrl,
  alt,
  onClose,
}) => {
  useEffect(() => {
    if (!imageUrl) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [imageUrl, onClose]);

  if (!imageUrl) return null;

  return (
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-black/85 p-4"
      role="dialog"
      aria-modal="true"
      aria-label="Pratinjau foto dokumentasi"
      onClick={onClose}
    >
      <div
        className="relative flex h-full max-h-[92vh] w-full max-w-6xl items-center justify-center"
        onClick={(event) => event.stopPropagation()}
      >
        <img
          src={imageUrl}
          alt={alt}
          className="h-full w-full object-contain"
        />
        <button
          type="button"
          onClick={onClose}
          className="absolute right-2 top-2 rounded-full bg-black/65 p-2 text-white transition-colors hover:bg-black/85 focus:outline-none focus:ring-2 focus:ring-white"
          aria-label="Tutup pratinjau foto"
        >
          <X className="h-6 w-6" />
        </button>
      </div>
    </div>
  );
};
