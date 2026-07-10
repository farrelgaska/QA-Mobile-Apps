import React from 'react';
import { cn } from '../../utils/cn';

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  icon?: React.ReactNode;
  fullWidth?: boolean;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, icon, fullWidth = true, className, type = 'text', id, ...props }, ref) => {
    return (
      <div className={cn('flex flex-col space-y-1.5', fullWidth ? 'w-full' : 'w-auto')}>
        {label && (
          <label htmlFor={id} className="text-xs font-semibold text-gray-700 select-none">
            {label}
          </label>
        )}
        <div className="relative rounded-lg shadow-sm">
          {icon && (
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400">
              {icon}
            </div>
          )}
          <input
            id={id}
            type={type}
            className={cn(
              'block rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 transition-all duration-200 placeholder:text-gray-400 focus:border-[#006B5A] focus:outline-none focus:ring-1 focus:ring-[#006B5A] disabled:cursor-not-allowed disabled:bg-gray-50 disabled:text-gray-500',
              icon && 'pl-10',
              error && 'border-red-500 focus:border-red-500 focus:ring-red-500',
              fullWidth ? 'w-full' : 'w-auto',
              className
            )}
            ref={ref}
            {...props}
          />
        </div>
        {error && <span className="text-xs font-medium text-red-500">{error}</span>}
      </div>
    );
  }
);

Input.displayName = 'Input';
