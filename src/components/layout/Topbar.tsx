import React from 'react';
import { Search, User } from 'lucide-react';
import { cn } from '../../utils/cn';

export interface TopbarProps {
  title: string;
  adminName?: string;
  avatarUrl?: string;
  searchPlaceholder?: string;
  onSearchChange?: (val: string) => void;
  className?: string;
}

export const Topbar: React.FC<TopbarProps> = ({
  title,
  adminName = 'Budi Santoso',
  avatarUrl,
  searchPlaceholder,
  onSearchChange,
  className,
}) => {
  return (
    <header
      className={cn(
        'h-[74px] bg-white/80 backdrop-blur-md border-b border-gray-200/80 fixed top-0 right-0 left-[260px] flex items-center justify-between px-8 z-10 transition-all duration-200',
        className
      )}
    >
      <div className="flex items-center gap-6 flex-1 max-w-md">
        <h2 className="text-lg font-bold text-gray-800 tracking-tight whitespace-nowrap">{title}</h2>
        {searchPlaceholder && (
          <div className="relative w-full max-w-xs hidden md:block">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
            <input
              type="text"
              placeholder={searchPlaceholder}
              onChange={(e) => onSearchChange?.(e.target.value)}
              className="w-full bg-gray-50 hover:bg-gray-100/85 focus:bg-white text-xs px-3 py-2 pl-9 rounded-lg border border-transparent focus:border-gray-200 focus:outline-none focus:ring-1 focus:ring-[#006B5A] transition-all"
            />
          </div>
        )}
      </div>

      <div className="flex items-center gap-4">
        <div className="text-right hidden sm:block">
          <div className="text-sm font-semibold text-gray-800 leading-none">{adminName}</div>
          <span className="text-[10px] font-bold text-gray-400 tracking-wide uppercase">QC Admin Officer</span>
        </div>

        <div className="h-10 w-10 rounded-full border border-gray-200/60 bg-gray-50 flex items-center justify-center text-gray-600 overflow-hidden shadow-inner">
          {avatarUrl ? (
            <img src={avatarUrl} alt={adminName} className="h-full w-full object-cover" />
          ) : (
            <User className="h-5 w-5 text-[#006B5A]" />
          )}
        </div>
      </div>
    </header>
  );
};
