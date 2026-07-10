import React from 'react';
import { cn } from '../../utils/cn';

export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  color?: 'gray' | 'green' | 'yellow' | 'red' | 'blue' | 'orange';
  children: React.ReactNode;
}

export const Badge: React.FC<BadgeProps> = ({
  color = 'gray',
  className,
  children,
  ...props
}) => {
  const colors = {
    gray: 'bg-gray-100 text-gray-700 border border-gray-200/50',
    green: 'bg-[#E6F4F1] text-[#006B5A] border border-[#B3DED7]',
    yellow: 'bg-amber-55/40 text-amber-800 border border-amber-200/40 bg-amber-50',
    red: 'bg-red-50 text-red-700 border border-red-250/30 border-red-200/50',
    blue: 'bg-blue-50 text-blue-700 border border-blue-200/50',
    orange: 'bg-orange-50 text-orange-700 border border-orange-200/50',
  };

  return (
    <span
      className={cn(
        'inline-flex items-center justify-center text-center px-3 py-1 rounded-full text-xs font-semibold select-none transition-colors duration-150',
        colors[color],
        className
      )}
      {...props}
    >
      {children}
    </span>
  );
};
