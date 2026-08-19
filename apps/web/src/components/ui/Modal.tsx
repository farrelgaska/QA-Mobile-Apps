import React, { useEffect } from 'react';
import { X } from 'lucide-react';
import { cn } from '../../utils/cn';

export interface ModalProps {
  open?: boolean;
  isOpen?: boolean; // fallback for backwards compatibility
  onClose: () => void;
  title: string;
  children: React.ReactNode;
  footer?: React.ReactNode;
  className?: string;
}

export const Modal: React.FC<ModalProps> = ({
  open,
  isOpen,
  onClose,
  title,
  children,
  footer,
  className,
}) => {
  const show = open !== undefined ? open : isOpen;

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && show) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [show, onClose]);

  useEffect(() => {
    if (show) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [show]);

  if (!show) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm transition-opacity duration-300"
        onClick={onClose}
      />

      <div
        className={cn(
          'relative bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden z-10 transition-all duration-300 transform scale-100 flex flex-col max-h-[90vh]',
          className
        )}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 bg-gray-50/30">
          <h3 className="font-bold text-gray-800 text-lg leading-6">{title}</h3>
          <button
            onClick={onClose}
            className="rounded-lg p-1.5 text-gray-400 hover:text-gray-650 hover:bg-gray-100 transition-all duration-150 focus:outline-none focus:ring-2 focus:ring-[#006B5A]"
            aria-label="Close dialog"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="flex-1 px-6 py-5 overflow-y-auto text-sm text-gray-600 leading-relaxed">
          {children}
        </div>

        {footer && (
          <div className="flex items-center justify-end gap-3 px-6 py-4 border-t border-gray-100 bg-gray-50/50">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
};
