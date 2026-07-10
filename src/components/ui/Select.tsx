import React, { useState, useRef, useEffect } from 'react';
import { cn } from '../../utils/cn';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown } from 'lucide-react';

export interface SelectOption {
  value: string;
  label: string;
}

export interface SelectProps {
  label?: string;
  options: SelectOption[];
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  error?: string;
  fullWidth?: boolean;
  className?: string;
  id?: string;
}

export const Select: React.FC<SelectProps> = ({
  label,
  options,
  value,
  onChange,
  placeholder,
  error,
  fullWidth = true,
  className,
  id,
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  // Close dropdown on click outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Close dropdown on escape key
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setIsOpen(false);
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, []);

  const selectedOption = options.find((opt) => opt.value === value);

  return (
    <div
      ref={containerRef}
      className={cn('flex flex-col space-y-1.5 relative z-[100]', fullWidth ? 'w-full' : 'w-auto')}
    >
      {label && (
        <label className="text-xs font-semibold text-gray-700 select-none">
          {label}
        </label>
      )}
      <div className="relative">
        <button
          id={id}
          type="button"
          onClick={() => setIsOpen(!isOpen)}
          className={cn(
            'relative flex h-10 w-full items-center justify-between rounded-xl border border-gray-300 bg-white px-3 text-sm font-medium text-gray-800 shadow-sm transition-all duration-200 hover:border-[#006B5A]/40 focus:border-[#006B5A] focus:outline-none focus:ring-4 focus:ring-[#006B5A]/10 text-left',
            error && 'border-red-500 focus:border-red-500 focus:ring-red-500/20',
            className
          )}
        >
          <span className="block truncate">
            {selectedOption ? selectedOption.label : placeholder || 'Pilih opsi'}
          </span>
          <ChevronDown
            className={cn(
              'h-4 w-4 text-gray-400 transition-transform duration-200 flex-shrink-0 ml-2',
              isOpen ? 'rotate-180 text-[#006B5A]' : 'rotate-0'
            )}
          />
        </button>

        <AnimatePresence>
          {isOpen && (
            <motion.div
              initial={{ opacity: 0, y: -6, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -6, scale: 0.98 }}
              transition={{ duration: 0.15, ease: [0.22, 1, 0.36, 1] }}
              className="absolute left-0 top-full z-[9999] mt-1.5 max-h-60 w-full overflow-y-auto rounded-xl border border-gray-200 bg-white shadow-xl py-1"
            >
              {options.length === 0 ? (
                <div className="px-4 py-2.5 text-sm text-gray-400 italic">
                  Tidak ada opsi
                </div>
              ) : (
                options.map((opt) => {
                  const isSelected = opt.value === value;
                  return (
                    <button
                      key={opt.value}
                      type="button"
                      onClick={() => {
                        onChange(opt.value);
                        setIsOpen(false);
                      }}
                      className={cn(
                        'w-full px-4 py-2.5 text-left text-sm transition-colors duration-150 block truncate',
                        isSelected
                          ? 'bg-[#E6F4F1] text-[#006B5A] font-semibold'
                          : 'text-gray-700 hover:bg-gray-50'
                      )}
                    >
                      {opt.label}
                    </button>
                  );
                })
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
      {error && <span className="text-xs font-medium text-red-500">{error}</span>}
    </div>
  );
};
