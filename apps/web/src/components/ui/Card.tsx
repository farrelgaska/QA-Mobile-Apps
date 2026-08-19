import React from 'react';
import { cn } from '../../utils/cn';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  title?: string;
  extra?: React.ReactNode;
}

export const Card: React.FC<CardProps> = ({
  title,
  extra,
  className,
  children,
  ...props
}) => {
  const hasLegacyHeader = title || extra;

  return (
    <div
      className={cn(
        'bg-white rounded-xl border border-gray-200/80 shadow-sm transition-all duration-300 hover:shadow-md overflow-hidden',
        className
      )}
      {...props}
    >
      {hasLegacyHeader && (
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3 border-b border-gray-100">
          {title && <CardTitle>{title}</CardTitle>}
          {extra && <div>{extra}</div>}
        </CardHeader>
      )}
      {hasLegacyHeader ? (
        <CardContent className="pt-4">{children}</CardContent>
      ) : (
        children
      )}
    </div>
  );
};

export interface CardHeaderProps extends React.HTMLAttributes<HTMLDivElement> {}

export const CardHeader: React.FC<CardHeaderProps> = ({ className, ...props }) => {
  return (
    <div
      className={cn('flex flex-col space-y-1.5 p-6 border-b border-gray-100/80 bg-gray-50/20', className)}
      {...props}
    />
  );
};

export interface CardTitleProps extends React.HTMLAttributes<HTMLHeadingElement> {}

export const CardTitle: React.FC<CardTitleProps> = ({ className, ...props }) => {
  return (
    <h3
      className={cn(
        'text-base font-bold text-gray-800 tracking-tight leading-none',
        className
      )}
      {...props}
    />
  );
};

export interface CardContentProps extends React.HTMLAttributes<HTMLDivElement> {}

export const CardContent: React.FC<CardContentProps> = ({ className, ...props }) => {
  return <div className={cn('p-6 pt-5', className)} {...props} />;
};
