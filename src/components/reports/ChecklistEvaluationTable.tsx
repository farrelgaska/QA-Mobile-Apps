import React, { useState } from 'react';
import type { ChecklistItem, ChecklistResult } from '../../types/report';
import { Table, TableHeader, TableRow, TableCell, TableBody } from '../ui/Table';
import { StandardResultBadge } from './StandardResultBadge';
import { Image as ImageIcon, MessageSquare, Check, X, AlertCircle } from 'lucide-react';
import { Modal } from '../ui/Modal';

export interface ChecklistEvaluationTableProps {
  items: ChecklistItem[];
  isEditable?: boolean;
  onUpdateItem?: (itemId: string, result: ChecklistResult, note: string) => void;
}

export const ChecklistEvaluationTable: React.FC<ChecklistEvaluationTableProps> = ({ 
  items,
  isEditable = false,
  onUpdateItem
}) => {
  const [editingItem, setEditingItem] = useState<{
    id: string;
    name: string;
    result: ChecklistResult;
    note: string;
  } | null>(null);

  const getShortPreview = (note?: string) => {
    if (!note?.trim()) return 'Tambah catatan...';
    return note.length > 50 ? note.substring(0, 47) + '...' : note;
  };

  return (
    <>
      <div className="overflow-x-auto rounded-xl border border-gray-150 bg-white">
      <Table>
        <TableHeader>
          <TableRow>
            <TableCell isHeader className="w-12 text-center">No</TableCell>
            <TableCell isHeader>Parameter QC</TableCell>
            <TableCell isHeader>Acuan Standar</TableCell>
            <TableCell isHeader>Nilai Aktual Lapangan</TableCell>
            <TableCell isHeader>Hasil Evaluasi</TableCell>
            <TableCell isHeader>Foto Dokumentasi</TableCell>
            <TableCell isHeader>Catatan Admin</TableCell>
          </TableRow>
        </TableHeader>
        <TableBody>
          {items.length === 0 ? (
            <TableRow>
              <TableCell colSpan={7} className="text-center py-8 text-gray-400">
                Tidak ada parameter checklist.
              </TableCell>
            </TableRow>
          ) : (
            items.map((item, idx) => (
              <TableRow key={item.id} className="align-middle hover:bg-gray-50/55 transition-colors duration-150">
                <TableCell className="text-center font-medium text-gray-400">{idx + 1}</TableCell>
                <TableCell className="font-semibold text-gray-800">{item.name}</TableCell>
                <TableCell className="text-gray-500 font-medium">{item.standardLabel}</TableCell>
                <TableCell className="font-bold text-gray-700">
                  {item.actualValue ? `${item.actualValue} ${item.unit || ''}` : <span className="text-gray-300 font-normal italic">Kosong</span>}
                </TableCell>
                <TableCell>
                  {isEditable && onUpdateItem ? (
                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        onClick={(e) => {
                          e.preventDefault();
                          e.stopPropagation();
                          onUpdateItem(item.id, 'PASS', item.adminNote || '');
                        }}
                        className={`p-1.5 rounded-lg border transition-all duration-150 flex items-center gap-1 text-xs font-semibold ${
                          item.result === 'PASS'
                            ? 'bg-emerald-50 border-emerald-300 text-emerald-700 shadow-sm'
                            : 'bg-white border-gray-200 text-gray-400 hover:bg-gray-50 hover:text-gray-600'
                        }`}
                        title="Set Lulus"
                      >
                        <Check className="h-3.5 w-3.5" />
                        <span>Lulus</span>
                      </button>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.preventDefault();
                          e.stopPropagation();
                          onUpdateItem(item.id, 'FAIL', item.adminNote || '');
                        }}
                        className={`p-1.5 rounded-lg border transition-all duration-150 flex items-center gap-1 text-xs font-semibold ${
                          item.result === 'FAIL'
                            ? 'bg-rose-50 border-rose-300 text-rose-700 shadow-sm'
                            : 'bg-white border-gray-200 text-gray-400 hover:bg-gray-50 hover:text-gray-600'
                        }`}
                        title="Set Tidak Lulus"
                      >
                        <X className="h-3.5 w-3.5" />
                        <span>Gagal</span>
                      </button>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.preventDefault();
                          e.stopPropagation();
                          onUpdateItem(item.id, 'NEEDS_REVIEW', item.adminNote || '');
                        }}
                        className={`p-1.5 rounded-lg border transition-all duration-150 flex items-center gap-1 text-xs font-semibold ${
                          item.result === 'NEEDS_REVIEW'
                            ? 'bg-amber-50 border-amber-300 text-amber-750 shadow-sm'
                            : 'bg-white border-gray-200 text-gray-400 hover:bg-gray-50 hover:text-gray-600'
                        }`}
                        title="Set Perlu Review"
                      >
                        <AlertCircle className="h-3.5 w-3.5" />
                        <span>Review</span>
                      </button>
                    </div>
                  ) : (
                    <StandardResultBadge result={item.result} />
                  )}
                </TableCell>
                <TableCell>
                  <div className="flex flex-wrap gap-1.5">
                    {item.photoUrls && item.photoUrls.length > 0 ? (
                      item.photoUrls.map((url, i) => (
                        <a
                          key={i}
                          href={url}
                          target="_blank"
                          rel="noreferrer"
                          className="group relative h-9 w-9 rounded-lg border border-gray-200 overflow-hidden inline-flex items-center justify-center hover:border-[#006B5A] bg-gray-50 hover:shadow-sm transition-all duration-150"
                          title="Lihat foto asli"
                        >
                          {url.startsWith('http') || url.startsWith('/') || url.startsWith('data:') ? (
                            <img
                              src={url}
                              alt={`${item.name} doc ${i + 1}`}
                              className="h-full w-full object-cover group-hover:scale-105 transition-transform duration-200"
                            />
                          ) : (
                            <ImageIcon className="h-4.5 w-4.5 text-gray-400 group-hover:text-[#006B5A]" />
                          )}
                        </a>
                      ))
                    ) : (
                      <span className="text-xs text-gray-400 italic">Tidak ada foto</span>
                    )}
                  </div>
                </TableCell>
                <TableCell className="max-w-[240px]">
                  {isEditable && onUpdateItem ? (
                    <button
                      type="button"
                      onClick={() => setEditingItem({
                        id: item.id,
                        name: item.name,
                        result: item.result,
                        note: item.adminNote || '',
                      })}
                      className={`w-full text-left flex items-start gap-1.5 text-xs p-2 rounded-lg transition-all duration-150 border focus:outline-none ${
                        item.adminNote
                          ? 'text-amber-700 bg-amber-50/50 border-amber-200/50 hover:bg-amber-100/50 hover:border-amber-300/50'
                          : 'text-gray-400 bg-gray-50/50 border-gray-150 hover:bg-gray-100/50 hover:border-gray-250 border-dashed'
                      }`}
                    >
                      <MessageSquare className="h-3.5 w-3.5 mt-0.5 flex-shrink-0" />
                      <span className="truncate max-w-[190px]">
                        {item.adminNote ? getShortPreview(item.adminNote) : 'Tambah catatan...'}
                      </span>
                    </button>
                  ) : item.adminNote ? (
                    <div className="flex items-start gap-1.5 text-xs text-amber-700 bg-amber-50/50 border border-amber-200/50 p-2 rounded-lg leading-relaxed">
                      <MessageSquare className="h-3.5 w-3.5 mt-0.5 flex-shrink-0" />
                      <span>{item.adminNote}</span>
                    </div>
                  ) : (
                    <span className="text-xs text-gray-400 italic">-</span>
                  )}
                </TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>

    <Modal
      open={!!editingItem}
      onClose={() => setEditingItem(null)}
      title={`Edit Catatan: ${editingItem?.name}`}
      footer={
        <div className="flex justify-end gap-2">
          <button
            type="button"
            onClick={() => setEditingItem(null)}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-305 rounded-lg hover:bg-gray-50 transition-colors duration-150"
          >
            Batal
          </button>
          <button
            type="button"
            onClick={() => {
              if (editingItem && onUpdateItem) {
                onUpdateItem(editingItem.id, editingItem.result, editingItem.note);
              }
              setEditingItem(null);
            }}
            className="px-4 py-2 text-sm font-medium text-white bg-[#006B5A] rounded-lg hover:bg-[#005749] transition-colors duration-150"
          >
            Simpan
          </button>
        </div>
      }
    >
      <div className="space-y-3">
        <label htmlFor="admin-note-textarea" className="block text-xs font-semibold text-gray-500 uppercase tracking-wider">
          Catatan Evaluasi Admin
        </label>
        <textarea
          id="admin-note-textarea"
          value={editingItem?.note || ''}
          onChange={(e) => setEditingItem(prev => prev ? { ...prev, note: e.target.value } : null)}
          placeholder="Masukkan catatan detail untuk parameter ini..."
          className="w-full h-32 px-3 py-2 border border-gray-200 rounded-lg focus:outline-none focus:ring-1 focus:ring-[#006B5A] focus:border-[#006B5A] text-sm text-gray-700 placeholder-gray-300 resize-none"
          autoFocus
        />
      </div>
    </Modal>
  </>
);
};
