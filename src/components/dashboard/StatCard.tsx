import React from 'react';
import { Card } from '../ui/Card';
import { cn } from '../../utils/cn';

export interface StatCardProps {
  title: string;
  value: number | string;
  icon?: React.ReactNode;
  tone?: 'green' | 'yellow' | 'red' | 'blue' | 'gray';
  description?: string;
  className?: string;
}

export const StatCard: React.FC<StatCardProps> = ({
  title,
  value,
  icon,
  tone = 'gray',
  description,
  className,
}) => {
  const tones = {
    green: {
      bg: 'bg-[#E6F4F1]',
      text: 'text-[#006B5A]',
      ring: 'group-hover:ring-[#006B5A]/20',
    },
    yellow: {
      bg: 'bg-amber-50',
      text: 'text-amber-700',
      ring: 'group-hover:ring-amber-500/20',
    },
    red: {
      bg: 'bg-red-50',
      text: 'text-red-650 text-red-600',
      ring: 'group-hover:ring-red-500/20',
    },
    blue: {
      bg: 'bg-blue-50',
      text: 'text-blue-600',
      ring: 'group-hover:ring-blue-500/20',
    },
    gray: {
      bg: 'bg-gray-50',
      text: 'text-gray-600',
      ring: 'group-hover:ring-gray-400/20',
    },
  };

  return (
    <Card className={cn('group overflow-hidden transition-all duration-300', className)}>
      <div className="flex items-center justify-between p-6">
        <div className="space-y-1">
          <span className="text-[11px] font-bold text-gray-400 tracking-wider uppercase block">
            {title}
          </span>
          <span className="text-3xl font-extrabold text-gray-800 tracking-tight block">
            {value}
          </span>
          {description && (
            <p className="text-xs text-gray-400 font-medium pt-1">
              {description}
            </p>
          )}
        </div>
        {icon && (
          <div
            className={cn(
              'h-12 w-12 rounded-xl flex items-center justify-center transition-all duration-300 ring-4 ring-transparent',
              tones[tone].bg,
              tones[tone].text,
              tones[tone].ring
            )}
          >
            {icon}
          </div>
        )}
      </div>
    </Card>
  );
};
