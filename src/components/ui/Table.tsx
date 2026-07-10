import React from 'react';
import { cn } from '../../utils/cn';

export interface TableProps extends React.TableHTMLAttributes<HTMLTableElement> {
  headers?: string[];
}

export const Table: React.FC<TableProps> = ({
  headers,
  className,
  children,
  ...props
}) => {
  return (
    <div className="w-full overflow-x-auto rounded-xl border border-gray-200/80 bg-white shadow-sm">
      <table className={cn('w-full text-left border-collapse text-sm', className)} {...props}>
        {headers ? (
          <>
            <TableHeader>
              <TableRow className="hover:bg-transparent bg-gray-50/50">
                {headers.map((h, idx) => (
                  <TableCell key={idx} isHeader className="font-bold text-gray-700">
                    {h}
                  </TableCell>
                ))}
              </TableRow>
            </TableHeader>
            <TableBody>{children}</TableBody>
          </>
        ) : (
          children
        )}
      </table>
    </div>
  );
};

export interface TableHeaderProps extends React.HTMLAttributes<HTMLTableSectionElement> {}

export const TableHeader: React.FC<TableHeaderProps> = ({ className, ...props }) => {
  return (
    <thead
      className={cn('bg-gray-50/60 border-b border-gray-250/20 border-gray-200/80', className)}
      {...props}
    />
  );
};

export interface TableBodyProps extends React.HTMLAttributes<HTMLTableSectionElement> {}

export const TableBody: React.FC<TableBodyProps> = ({ className, ...props }) => {
  return <tbody className={cn('divide-y divide-gray-100 bg-white', className)} {...props} />;
};

export interface TableRowProps extends React.HTMLAttributes<HTMLTableRowElement> {}

export const TableRow: React.FC<TableRowProps> = ({ className, ...props }) => {
  return (
    <tr
      className={cn(
        'transition-colors duration-150 hover:bg-gray-50/70',
        className
      )}
      {...props}
    />
  );
};

export interface TableCellProps extends React.TdHTMLAttributes<HTMLTableCellElement> {
  isHeader?: boolean;
}

export const TableCell: React.FC<TableCellProps> = ({
  isHeader = false,
  className,
  ...props
}) => {
  const Component = isHeader ? 'th' : 'td';
  return (
    <Component
      className={cn(
        'px-6 py-4 font-medium text-gray-650 text-gray-650',
        isHeader && 'text-xs font-bold text-gray-500 uppercase tracking-wider',
        className
      )}
      {...props}
    />
  );
};
