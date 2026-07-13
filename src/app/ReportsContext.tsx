import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import type { QCReport, StandardResult } from '../types/report';
import { dummyReports } from '../data/dummyReports';
import { normalizeReportStatus, mapToSharedReport } from '../utils/status';
import {
  fetchReports,
  approveReportApi,
  requestFollowUpApi,
  type ApiChecklistItem,
} from '../services/reportApi';

// ─── Types ───────────────────────────────────────────────────────────────────

interface ReportsContextValue {
  reports: QCReport[];
  loading: boolean;
  error: string | null;
  refetch: () => void;
  getReport: (id: string) => QCReport | undefined;
  approveReport: (id: string, adminNote?: string) => Promise<void>;
  requestRevision: (id: string, adminNote: string) => Promise<void>;
  updateChecklistItem: (
    reportId: string,
    itemId: string,
    result: 'PASS' | 'FAIL' | 'NEEDS_REVIEW',
    adminNote: string
  ) => void;
}

// ─── Context ─────────────────────────────────────────────────────────────────

const ReportsContext = createContext<ReportsContextValue | null>(null);

// ─── Local-state helpers (fallback) ──────────────────────────────────────────

const STORAGE_KEY = 'reports_v2';

function saveToStorage(reports: QCReport[]): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(reports));
  } catch {
    // ignore quota errors
  }
}

/** Map QCReport's legacy checklistItems back to ApiChecklistItem format for PATCH. */
function buildApiChecklistItems(report: QCReport): ApiChecklistItem[] {
  return (report.checklist_items ?? []).map(item => ({
    id: item.id,
    parameter_name: item.parameter_name,
    input_type: item.input_type,
    standard_text: item.standard_text,
    unit: item.unit,
    actual_value: item.actual_value,
    staff_note: item.staff_note,
    item_photos: item.item_photos,
    admin_evaluation: item.admin_evaluation as 'PASS' | 'FAIL' | 'NEEDS_REVIEW' | 'PENDING',
    admin_note: item.admin_note,
  }));
}

// ─── Provider ─────────────────────────────────────────────────────────────────

export const ReportsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [reports, setReports] = useState<QCReport[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Keep a stable ref to current reports for use inside callbacks
  const reportsRef = useRef<QCReport[]>(reports);
  useEffect(() => { reportsRef.current = reports; }, [reports]);

  // ── Load reports from API ──────────────────────────────────────────────────
  const loadReports = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const apiData = await fetchReports();
      const mapped = apiData.map((r: any) => mapToSharedReport(r));
      setReports(mapped);
      saveToStorage(mapped);
    } catch (err) {
      // API offline: fall back to localStorage, then to dummy data
      console.warn('[Mock API offline] Falling back to local data.', err);
      try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (raw) {
          const parsed = JSON.parse(raw) as QCReport[];
          setReports(parsed.map(r => mapToSharedReport(r)));
        } else {
          // Last resort: use dummy data, filter out DRAFT (staff-only)
          setReports(dummyReports.filter(r => r.status !== 'DRAFT').map(r => mapToSharedReport(r)));
        }
      } catch {
        setReports(dummyReports.filter(r => r.status !== 'DRAFT').map(r => mapToSharedReport(r)));
      }
      setError('Tidak dapat terhubung ke server. Menampilkan data lokal.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadReports();
  }, [loadReports]);

  // ── Local optimistic update helper ────────────────────────────────────────

  const applyLocalUpdate = useCallback((updatedReport: QCReport) => {
    const mapped = mapToSharedReport(updatedReport);
    setReports(prev => {
      const next = prev.map(r => r.id === mapped.id ? mapped : r);
      saveToStorage(next);
      return next;
    });
  }, []);

  // ── Selectors ─────────────────────────────────────────────────────────────

  const getReport = useCallback(
    (id: string) => reportsRef.current.find(r => r.id === id),
    []
  );

  // ── Approve report ────────────────────────────────────────────────────────

  const approveReport = useCallback(async (id: string, adminNote?: string) => {
    const report = reportsRef.current.find(r => r.id === id);
    if (!report) throw new Error('Report not found.');

    // Enforce approval rules: every item must be PASS
    const allPass = report.checklistItems.every(i => i.result === 'PASS');
    if (!allPass) throw new Error('Approval is blocked: not all items are PASS.');

    const updatedChecklist = buildApiChecklistItems(report);
    const note = adminNote || 'Laporan disetujui. Semua kriteria memenuhi standar teknis.';

    // Optimistic update first
    const optimistic: QCReport = {
      ...report,
      status: 'APPROVED',
      standardResult: 'Lulus',
      adminNote: note,
      admin_review: {
        ...report.admin_review,
        admin_note: note,
        conclusion: 'PASSED',
        reviewed_at: new Date().toISOString(),
      },
    };
    applyLocalUpdate(optimistic);

    // Persist to API (best-effort, non-blocking for UI)
    try {
      const updated = await approveReportApi(id, note, 'Admin', updatedChecklist);
      applyLocalUpdate(mapToSharedReport(updated));
    } catch (err) {
      console.warn('[Mock API offline] Approval saved locally only.', err);
    }
  }, [applyLocalUpdate]);

  // ── Request follow-up ─────────────────────────────────────────────────────

  const requestRevision = useCallback(async (id: string, adminNote: string) => {
    const report = reportsRef.current.find(r => r.id === id);
    if (!report) throw new Error('Report not found.');

    const hasFail = report.checklistItems.some(i => i.result === 'FAIL');
    if (!hasFail) throw new Error('Revision requires at least one FAIL item.');

    const failedWithoutNotes = report.checklistItems.filter(i => i.result === 'FAIL' && !i.adminNote?.trim());
    if (failedWithoutNotes.length > 0) throw new Error('Every failed item must have an Admin note.');

    const updatedChecklist = buildApiChecklistItems(report);

    // Optimistic update
    const optimistic: QCReport = {
      ...report,
      status: 'NEEDS_FOLLOW_UP',
      standardResult: 'Tidak Lulus',
      adminNote,
      admin_review: {
        ...report.admin_review,
        admin_note: adminNote,
        conclusion: 'NEEDS_FOLLOW_UP',
        reviewed_at: new Date().toISOString(),
      },
    };
    applyLocalUpdate(optimistic);

    // Persist to API (best-effort)
    try {
      const updated = await requestFollowUpApi(id, adminNote, 'Admin', updatedChecklist);
      applyLocalUpdate(mapToSharedReport(updated));
    } catch (err) {
      console.warn('[Mock API offline] Follow-up request saved locally only.', err);
    }
  }, [applyLocalUpdate]);

  // ── Update single checklist item (local only, stays until approve/revision) ─

  const updateChecklistItem = useCallback((
    reportId: string,
    itemId: string,
    result: 'PASS' | 'FAIL' | 'NEEDS_REVIEW',
    adminNote: string
  ) => {
    const report = reportsRef.current.find(r => r.id === reportId);
    if (!report) return;

    const updatedItems = report.checklistItems.map(item =>
      item.id === itemId ? { ...item, result, adminNote } : item
    );

    // Also update shared checklist_items so buildApiChecklistItems picks up changes
    const updatedSharedItems = (report.checklist_items ?? []).map(item =>
      item.id === itemId
        ? { ...item, admin_evaluation: result as 'PASS' | 'FAIL' | 'NEEDS_REVIEW', admin_note: adminNote }
        : item
    );

    // Auto-recalculate standardResult
    let newStandardResult: StandardResult = 'Lulus';
    if (updatedItems.some(i => i.result === 'FAIL')) {
      newStandardResult = 'Tidak Lulus';
    } else if (updatedItems.some(i => i.result === 'NEEDS_REVIEW')) {
      newStandardResult = 'Perlu Review';
    }

    applyLocalUpdate({
      ...report,
      checklistItems: updatedItems,
      checklist_items: updatedSharedItems,
      standardResult: newStandardResult,
    });
  }, [applyLocalUpdate]);

  // ─── Context value ────────────────────────────────────────────────────────

  const value: ReportsContextValue = {
    reports,
    loading,
    error,
    refetch: loadReports,
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
