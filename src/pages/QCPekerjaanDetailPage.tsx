import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import type { QCPekerjaan, PekerjaanChecklistTemplate } from '../types/pekerjaan';
import {
  deleteTemplateChecklistItem,
  fetchTemplate,
  fetchTemplates,
  patchTemplate,
  patchTemplateChecklistItem,
  postTemplateChecklistItem,
} from '../services/reportApi';
import type { ApiTemplate, ApiTemplateChecklistItem, ApiTemplateChecklistItemMutation } from '../services/reportApi';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { PageTransition } from '../components/layout/PageTransition';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Table, TableHeader, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { TemplateParameterForm } from '../components/templates/TemplateParameterForm';
import { Pencil, Plus, Trash2, ShieldAlert } from 'lucide-react';

const mapApiToPekerjaan = (t: ApiTemplate): QCPekerjaan => ({
  id: t.id,
  formCode: t.formCode,
  name: t.name,
  category: t.category || '',
  description: t.description || '',
  segment: t.segment || 'construction',
  checklistCount: t.checklistItems?.length || 0,
  isActive: t.isActive,
  updatedAt: t.updatedAt || new Date().toISOString(),
  checklistItems: (t.checklistItems || []).map((item) => ({
    id: item.id,
    name: item.parameterName,
    inputType: item.inputType ?? 'choice',
    standardText: item.standardText ?? '',
    minValue: item.minValue ?? null,
    maxValue: item.maxValue ?? null,
    unit: item.unit ?? null,
    choiceOptions: item.choiceOptions ?? [],
    isRequired: item.isRequired ?? true,
    requiredPhoto: item.requiredPhoto ?? false,
    isActive: item.isActive,
    isCritical: item.isCritical ?? false,
    position: item.position
  }))
});

const pekerjaanItemToApi = (item: PekerjaanChecklistTemplate): ApiTemplateChecklistItem => ({
  id: item.id,
  parameterName: item.name,
  inputType: item.inputType ?? 'choice',
  standardText: item.standardText ?? '',
  minValue: item.minValue ?? null,
  maxValue: item.maxValue ?? null,
  unit: item.unit ?? null,
  choiceOptions: item.choiceOptions ?? [],
  choices: [],
  isRequired: item.isRequired ?? true,
  requiredPhoto: item.requiredPhoto ?? false,
  isActive: item.isActive,
  isCritical: item.isCritical ?? false,
  position: item.position ?? 0,
});

export const QCPekerjaanDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const location = useLocation();

  const [pekerjaanList, setPekerjaanList] = useState<QCPekerjaan[]>([]);
  const [template, setTemplate] = useState<QCPekerjaan | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const success = location.state?.successMessage || null;

  // Modal State
  const [isParameterModalOpen, setIsParameterModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<PekerjaanChecklistTemplate | null>(null);
  const [itemToDelete, setItemToDelete] = useState<string | null>(null);

  const loadData = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const all = await fetchTemplates();
      const list = all
        .filter(t => t.type === 'WORK')
        .map(mapApiToPekerjaan);
      setPekerjaanList(list);

      const found = list.find(w => w.id === id);
      if (found) {
        setTemplate(found);
      } else {
        setError('Template tidak ditemukan di server.');
      }
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal memuat template pekerjaan.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadData();
    if (location.state?.successMessage) window.history.replaceState({}, document.title);
  }, [id]);

  const refreshTemplate = async () => {
    if (!id) return;
    const refreshedTemplate = mapApiToPekerjaan(await fetchTemplate(id));
    setPekerjaanList(current => current.map(item => item.id === refreshedTemplate.id ? refreshedTemplate : item));
    setTemplate(refreshedTemplate);
  };

  const saveParameter = async (item: ApiTemplateChecklistItemMutation) => {
    if (!template) return;
    setIsLoading(true);
    setError(null);
    try {
      if (editingItem) await patchTemplateChecklistItem(template.id, editingItem.id, item);
      else await postTemplateChecklistItem(template.id, item);
      await refreshTemplate();
      setEditingItem(null);
      setIsParameterModalOpen(false);
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal memperbarui template.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDeleteItem = (itemId: string) => {
    setItemToDelete(itemId);
  };

  const confirmDelete = async () => {
    if (!template || !itemToDelete) return;

    setIsLoading(true);
    setError(null);
    try {
      const updatedTemplate = mapApiToPekerjaan(await deleteTemplateChecklistItem(template.id, itemToDelete));

      const updatedList = pekerjaanList.map(w => w.id === updatedTemplate.id ? updatedTemplate : w);
      setPekerjaanList(updatedList);
      setTemplate(updatedTemplate);
      setItemToDelete(null);
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal menghapus instruksi.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleToggleItemActive = async (itemId: string) => {
    if (!template) return;
    const item = template.checklistItems.find(candidate => candidate.id === itemId);
    if (!item) return;
    setIsLoading(true);
    setError(null);
    try {
      await patchTemplateChecklistItem(template.id, itemId, { isActive: !item.isActive });
      await refreshTemplate();
    } catch (e: any) {
      setError(e.message || 'Gagal mengubah status item.');
    } finally {
      setIsLoading(false);
    }
  };

  const changeTemplateStatus = async (isActive: boolean) => {
    if (!template || (isActive && template.checklistItems.length === 0)) return;
    setIsLoading(true);
    setError(null);
    try {
      await patchTemplate(template.id, { isActive });
      await refreshTemplate();
    } catch (e: any) {
      setError(e.message || 'Gagal mengubah status template.');
    } finally {
      setIsLoading(false);
    }
  };

  if (!template) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-gray-500">
        <ShieldAlert className="h-10 w-10 text-rose-500 mb-3" />
        <p className="font-semibold">Template Pekerjaan tidak ditemukan.</p>
        <Button variant="outline" className="mt-4" onClick={() => navigate('/data/qc-pekerjaan')}>
          Kembali ke Daftar
        </Button>
      </div>
    );
  }

  const getSegmentBadgeColor = (seg: string): 'blue' | 'green' | 'yellow' | 'gray' => {
    switch (seg) {
      case 'construction': return 'blue';
      case 'provisioning': return 'green';
      case 'assurance': return 'yellow';
      default: return 'gray';
    }
  };

  return (
    <PageTransition className="space-y-6 max-w-7xl mx-auto px-1">
      {success && (
        <div className="p-4 text-sm text-emerald-700 bg-emerald-50 rounded-lg border border-emerald-200">
          <strong>Sukses:</strong> {success}
        </div>
      )}
      {error && (
        <div className="p-4 text-sm text-red-700 bg-red-50 rounded-lg border border-red-200">
          <strong>Error:</strong> {error}
        </div>
      )}

      {isLoading && (
        <div className="p-3 text-sm text-blue-700 bg-blue-50 rounded-lg border border-blue-200 animate-pulse">
          Menyinkronkan data dengan API...
        </div>
      )}

      {/* Top Header Navigation */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Button variant="outline" onClick={() => navigate('/data/qc-pekerjaan')} className="hover:bg-gray-50" disabled={isLoading}>
            ← Kembali ke Master Pekerjaan
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => navigate(`/data/qc-pekerjaan/${id}/edit`)}
            className="text-xs text-gray-600 hover:text-gray-900"
          >
            Edit Template
          </Button>
        </div>
        <div className="flex items-center gap-2">
          <Badge color={getSegmentBadgeColor(template.segment)} className="text-xs uppercase tracking-wider font-semibold capitalize">
            {template.segment}
          </Badge>
          <span className="text-gray-300">|</span>
          <span className="text-xs text-gray-400 font-medium">Diupdate: {new Date(template.updatedAt).toLocaleDateString('id-ID')}</span>
        </div>
      </div>

      {/* Metadata Detail */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card title="Detail Spesifikasi Pekerjaan" className="md:col-span-1">
          <CardContent className="space-y-4 pt-2">
            <div>
              <div className="text-xs text-gray-400 font-semibold">ID/Kode Pekerjaan</div>
              <div className="text-sm font-bold text-gray-800">{template.formCode || '-'}</div>
              <div className="text-[10px] text-gray-400 mt-1">ID teknis: {template.id}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400 font-semibold">Nama Aktivitas</div>
              <div className="text-sm font-bold text-gray-800 leading-tight">{template.name}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400 font-semibold">Kategori Bidang</div>
              <div className="text-sm font-bold text-gray-800">{template.category}</div>
            </div>
            {template.description && (
              <div>
                <div className="text-xs text-gray-400 font-semibold">Deskripsi</div>
                <div className="text-sm text-gray-700">{template.description}</div>
              </div>
            )}
            <div>
              <div className="text-xs text-gray-400 font-semibold">Status Kategori Master</div>
              <div className="mt-1">
                {template.isActive ? (
                  <span className="inline-flex items-center text-xs font-semibold text-emerald-700 bg-emerald-50 px-2 py-1 rounded-full border border-emerald-200">
                    Aktif digunakan
                  </span>
                ) : (
                  <span className="inline-flex items-center text-xs font-semibold text-gray-500 bg-gray-50 px-2 py-1 rounded-full border border-gray-200">
                    Nonaktif
                  </span>
                )}
              </div>
              <Button
                size="sm"
                variant={template.isActive ? 'outline' : 'primary'}
                className="mt-3"
                disabled={isLoading || (!template.isActive && template.checklistItems.length === 0)}
                onClick={() => changeTemplateStatus(!template.isActive)}
              >
                {template.isActive ? 'Nonaktifkan Template' : 'Aktifkan / Publikasikan'}
              </Button>
              {!template.isActive && template.checklistItems.length === 0 && (
                <p className="mt-2 text-xs text-amber-600">Tambahkan minimal satu parameter sebelum template diaktifkan.</p>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Checklist Item Parameters Area */}
        <div className="md:col-span-2 space-y-6">
          <Card title="Daftar Instruksi Checklist Uji">
            <div className="flex justify-between items-center px-6 py-3 border-b border-gray-100 bg-gray-50/50">
              <p className="text-xs text-gray-500">Langkah-langkah pemeriksaan fisik/teknis yang wajib divalidasi staf lapangan.</p>
              <Button
                onClick={() => { setEditingItem(null); setIsParameterModalOpen(true); }}
                size="sm"
                className="bg-[#006B5A] hover:bg-[#005244] text-white flex-shrink-0 ml-4"
              >
                <Plus className="mr-1.5 h-4 w-4" />
                Tambah Instruksi
              </Button>
            </div>
            <CardContent className="p-0">
              <div className="overflow-x-auto rounded-b-xl border-t border-gray-150">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableCell isHeader className="w-12 text-center">No</TableCell>
                      <TableCell isHeader>ID Item</TableCell>
                      <TableCell isHeader>Deskripsi Instruksi / Parameter Uji</TableCell>
                      <TableCell isHeader className="text-center">Status Uji</TableCell>
                      <TableCell isHeader className="text-center">Aksi</TableCell>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {!template.checklistItems || template.checklistItems.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={5} className="text-center py-12 text-gray-400 italic">
                          Belum ada instruksi checklist. Klik "Tambah Instruksi" untuk menambahkan.
                        </TableCell>
                      </TableRow>
                    ) : (
                      template.checklistItems.map((item, idx) => (
                        <TableRow key={item.id} className="hover:bg-gray-50/50">
                          <TableCell className="text-center text-gray-400 font-medium">{idx + 1}</TableCell>
                          <TableCell className="font-bold text-gray-500 text-xs">{item.id}</TableCell>
                          <TableCell className="font-semibold text-gray-800">{item.name}</TableCell>
                          <TableCell className="text-center">
                            <button
                              type="button"
                              onClick={() => { setEditingItem(item); setIsParameterModalOpen(true); }}
                              className="text-[#006B5A] hover:text-[#005244] p-1.5 rounded-lg hover:bg-emerald-50 transition-colors"
                              title="Edit Item"
                            >
                              <Pencil className="h-4 w-4" />
                            </button>
                            <button
                              type="button"
                              onClick={() => handleToggleItemActive(item.id)}
                              className="focus:outline-none"
                              title="Klik untuk ubah keaktifan item"
                            >
                              {item.isActive ? (
                                <span className="inline-flex items-center text-[10px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded cursor-pointer border border-emerald-100">
                                  AKTIF
                                </span>
                              ) : (
                                <span className="inline-flex items-center text-[10px] font-bold text-gray-400 bg-gray-50 px-2 py-0.5 rounded cursor-pointer border border-gray-200">
                                  MATI
                                </span>
                              )}
                            </button>
                          </TableCell>
                          <TableCell className="text-center">
                            <button
                              type="button"
                              onClick={() => handleDeleteItem(item.id)}
                              className="text-rose-500 hover:text-rose-700 p-1.5 rounded-lg hover:bg-rose-50 transition-colors"
                              title="Hapus Item"
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          </TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>

      {/* Create/Edit Item Modal */}
      <Modal
        isOpen={isParameterModalOpen}
        onClose={() => { setIsParameterModalOpen(false); setEditingItem(null); }}
        title={editingItem ? 'Edit Item Checklist Pekerjaan' : 'Tambah Item Checklist Pekerjaan'}
      >
        <TemplateParameterForm
          initialItem={editingItem ? pekerjaanItemToApi(editingItem) : undefined}
          isSaving={isLoading}
          onCancel={() => { setIsParameterModalOpen(false); setEditingItem(null); }}
          onSubmit={saveParameter}
        />
      </Modal>

      {/* Delete Confirmation Modal */}
      <Modal
        isOpen={itemToDelete !== null}
        onClose={() => setItemToDelete(null)}
        title="Konfirmasi Hapus Instruksi"
      >
        <div className="space-y-4 pt-2">
          <p className="text-sm text-gray-500">
            Apakah Anda yakin ingin menghapus instruksi checklist ini? Tindakan ini tidak dapat dibatalkan.
          </p>
          <div className="flex justify-end gap-2 pt-4 border-t border-gray-100">
            <Button variant="outline" type="button" onClick={() => setItemToDelete(null)} disabled={isLoading}>
              Batal
            </Button>
            <Button
              variant="danger"
              type="button"
              onClick={confirmDelete}
              disabled={isLoading}
            >
              Hapus
            </Button>
          </div>
        </div>
      </Modal>
    </PageTransition>
  );
};
