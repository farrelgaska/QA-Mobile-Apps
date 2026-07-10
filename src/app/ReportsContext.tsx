import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type { QCReport, StandardResult } from '../types/report';
import { dummyReports } from '../data/dummyReports';

// ─── Types ───────────────────────────────────────────────────────────────────

interface ReportsContextValue {
  reports: QCReport[];
  getReport: (id: string) => QCReport | undefined;
  approveReport: (id: string, adminNote?: string) => void;
  requestRevision: (id: string, adminNote: string) => void;
  updateChecklistItem: (
    reportId: string,
    itemId: string,
    result: 'pass' | 'fail' | 'review',
    adminNote: string
  ) => void;
}

// ─── Context ─────────────────────────────────────────────────────────────────

const ReportsContext = createContext<ReportsContextValue | null>(null);

// ─── Helpers ──────────────────────────────────────────────────────────────────

const STORAGE_KEY = 'reports';

function loadFromStorage(): QCReport[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw) as QCReport[];
  } catch {
    // ignore malformed JSON
  }
  return dummyReports;
}

function saveToStorage(reports: QCReport[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(reports));
}

// ─── Provider ─────────────────────────────────────────────────────────────────

export const ReportsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [reports, setReports] = useState<QCReport[]>(() => loadFromStorage());

  // Persist every time reports change
  useEffect(() => {
    saveToStorage(reports);
  }, [reports]);

  const updateReport = useCallback((updatedReport: QCReport) => {
    setReports(prev => prev.map(r => r.id === updatedReport.id ? updatedReport : r));
  }, []);

  const getReport = useCallback(
    (id: string) => reports.find(r => r.id === id),
    [reports]
  );

  const approveReport = useCallback((id: string, adminNote?: string) => {
    const report = reports.find(r => r.id === id);
    if (!report) return;
    updateReport({
      ...report,
      status: 'Disetujui',
      standardResult: 'Lulus',
      adminNote: adminNote || 'Laporan disetujui. Semua kriteria memenuhi standar teknis.',
    });
  }, [reports, updateReport]);

  const requestRevision = useCallback((id: string, adminNote: string) => {
    const report = reports.find(r => r.id === id);
    if (!report) return;
    updateReport({
      ...report,
      status: 'Perlu Perbaikan',
      adminNote,
    });
  }, [reports, updateReport]);

  const updateChecklistItem = useCallback((
    reportId: string,
    itemId: string,
    result: 'pass' | 'fail' | 'review',
    adminNote: string
  ) => {
    const report = reports.find(r => r.id === reportId);
    if (!report) return;

    const updatedItems = report.checklistItems.map(item =>
      item.id === itemId ? { ...item, result, adminNote } : item
    );

    // Auto-recalculate standardResult
    let newStandardResult: StandardResult = 'Lulus';
    if (updatedItems.some(i => i.result === 'fail')) {
      newStandardResult = 'Tidak Lulus';
    } else if (updatedItems.some(i => i.result === 'review')) {
      newStandardResult = 'Perlu Review';
    }

    updateReport({ ...report, checklistItems: updatedItems, standardResult: newStandardResult });
  }, [reports, updateReport]);

  const value: ReportsContextValue = {
    reports,
    getReport,
    approveReport,
    requestRevision,
    updateChecklistItem,
  };

  return <ReportsContext.Provider value={value}>{children}</ReportsContext.Provider>;
};

// ─── Hook ─────────────────────────────────────────────────────────────────────

export function useReports(): ReportsContextValue {
  const ctx = useContext(ReportsContext);
  if (!ctx) {
    throw new Error('useReports must be used within a ReportsProvider');
  }
  return ctx;
}
