import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import type { QCReport, StandardResult } from '../types/report';
import { dummyReports } from '../data/dummyReports';
import { normalizeReportStatus, mapToSharedReport } from '../utils/status';

// ─── Types ───────────────────────────────────────────────────────────────────

interface ReportsContextValue {
  reports: QCReport[];
  getReport: (id: string) => QCReport | undefined;
  approveReport: (id: string, adminNote?: string) => void;
  requestRevision: (id: string, adminNote: string) => void;
  updateChecklistItem: (
    reportId: string,
    itemId: string,
    result: 'PASS' | 'FAIL' | 'NEEDS_REVIEW',
    adminNote: string
  ) => void;
}

// ─── Context ─────────────────────────────────────────────────────────────────

const ReportsContext = createContext<ReportsContextValue | null>(null);

// ─── Helpers ──────────────────────────────────────────────────────────────────

const STORAGE_KEY = 'reports';

function loadFromStorage(): QCReport[] {
  let loadedReports: QCReport[] = [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) {
      loadedReports = JSON.parse(raw) as QCReport[];
    } else {
      loadedReports = dummyReports;
    }
  } catch {
    loadedReports = dummyReports;
  }
  return loadedReports.map(r => mapToSharedReport(r));
}

function saveToStorage(reports: QCReport[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(reports));
}

// ─── Provider ─────────────────────────────────────────────────────────────────

export const ReportsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [reports, setReports] = useState<QCReport[]>(() => loadFromStorage());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Sync with Mock API on mount
  useEffect(() => {
    setLoading(true);
    fetch('http://localhost:3002/reports')
      .then(res => {
        if (!res.ok) throw new Error('API server returned error');
        return res.json();
      })
      .then(data => {
        const mapped = data.map((r: any) => mapToSharedReport(r));
        setReports(mapped);
        saveToStorage(mapped);
        setError(null);
      })
      .catch(err => {
        console.warn('[Mock API Offline - Prototype Fallback] Using local storage state.', err);
      })
      .finally(() => {
        setLoading(false);
      });
  }, []);

  const updateReport = useCallback((updatedReport: QCReport) => {
    const mapped = mapToSharedReport(updatedReport);
    setReports(prev => prev.map(r => r.id === mapped.id ? mapped : r));
    
    // Save to storage
    saveToStorage(reports.map(r => r.id === mapped.id ? mapped : r));

    // Async sync to Mock API
    fetch(`http://localhost:3002/reports/${mapped.id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(mapped),
    }).catch(err => {
      console.warn('[Mock API Offline - Prototype Fallback] Failed to sync report patch to server.', err);
    });
  }, [reports]);

  const getReport = useCallback(
    (id: string) => reports.find(r => r.id === id),
    [reports]
  );

  const approveReport = useCallback((id: string, adminNote?: string) => {
    const report = reports.find(r => r.id === id);
    if (!report) return;

    // Enforce Approval rules: every item must be PASS
    const allPass = report.checklistItems.every(i => i.result === 'PASS');
    if (!allPass) {
      throw new Error('Approval is blocked: not all items are PASS.');
    }

    updateReport({
      ...report,
      status: 'APPROVED',
      standardResult: 'Lulus',
      admin_review: {
        ...report.admin_review,
        admin_note: adminNote || 'Laporan disetujui. Semua kriteria memenuhi standar teknis.',
        conclusion: 'Lulus',
        reviewed_at: new Date().toISOString(),
      },
    });
  }, [reports, updateReport]);

  const requestRevision = useCallback((id: string, adminNote: string) => {
    const report = reports.find(r => r.id === id);
    if (!report) return;

    // Enforce Revision rules: at least one item must be FAIL
    const hasFail = report.checklistItems.some(i => i.result === 'FAIL');
    if (!hasFail) {
      throw new Error('Revision requires at least one FAIL item.');
    }

    // Enforce Revision rules: every failed item must have an Admin note
    const failedWithoutNotes = report.checklistItems.filter(i => i.result === 'FAIL' && !i.adminNote?.trim());
    if (failedWithoutNotes.length > 0) {
      throw new Error('Every failed item must have an Admin note.');
    }

    updateReport({
      ...report,
      status: 'NEEDS_FOLLOW_UP',
      standardResult: 'Tidak Lulus',
      admin_review: {
        ...report.admin_review,
        admin_note: adminNote,
        conclusion: 'Tidak Lulus',
        reviewed_at: new Date().toISOString(),
      },
    });
  }, [reports, updateReport]);

  const updateChecklistItem = useCallback((
    reportId: string,
    itemId: string,
    result: 'PASS' | 'FAIL' | 'NEEDS_REVIEW',
    adminNote: string
  ) => {
    const report = reports.find(r => r.id === reportId);
    if (!report) return;

    const updatedItems = report.checklistItems.map(item =>
      item.id === itemId ? { ...item, result, adminNote } : item
    );

    // Auto-recalculate standardResult
    let newStandardResult: StandardResult = 'Lulus';
    if (updatedItems.some(i => i.result === 'FAIL')) {
      newStandardResult = 'Tidak Lulus';
    } else if (updatedItems.some(i => i.result === 'NEEDS_REVIEW')) {
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
