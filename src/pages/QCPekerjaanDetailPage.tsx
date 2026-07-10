import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import type { QCPekerjaan, PekerjaanChecklistTemplate } from '../types/pekerjaan';
import { dummyPekerjaan } from '../data/dummyPekerjaan';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { PageTransition } from '../components/layout/PageTransition';
import { Badge } from '../components/ui/Badge';
import { Input } from '../components/ui/Input';
import { Modal } from '../components/ui/Modal';
import { Table, TableHeader, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Plus, Trash2, ShieldAlert, Info } from 'lucide-react';

export const QCPekerjaanDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [pekerjaanList, setPekerjaanList] = useState<QCPekerjaan[]>([]);
  const [template, setTemplate] = useState<QCPekerjaan | null>(null);

  // Modal State
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [newItemName, setNewItemName] = useState('');

  useEffect(() => {
    const stored = localStorage.getItem('pekerjaan');
    const list: QCPekerjaan[] = stored ? JSON.parse(stored) : dummyPekerjaan;
    setPekerjaanList(list);

    const found = list.find(w => w.id === id);
    if (found) {
      setTemplate(found);
    }
  }, [id]);

  const updatePekerjaanTemplate = (updatedTemplate: QCPekerjaan) => {
    const updatedList = pekerjaanList.map(w => w.id === updatedTemplate.id ? updatedTemplate : w);
    setPekerjaanList(updatedList);
    setTemplate(updatedTemplate);
    localStorage.setItem('pekerjaan', JSON.stringify(updatedList));
  };

  const handleDeleteItem = (itemId: string) => {
    if (!template) return;

    const updatedItems = template.checklistItems.filter(item => item.id !== itemId);
    const updatedTemplate: QCPekerjaan = {
      ...template,
      checklistItems: updatedItems,
      checklistCount: updatedItems.length,
      updatedAt: new Date().toISOString()
    };

    updatePekerjaanTemplate(updatedTemplate);
  };

  const handleToggleItemActive = (itemId: string) => {
    if (!template) return;

    const updatedItems = template.checklistItems.map(item => {
      if (item.id === itemId) {
        return { ...item, isActive: !item.isActive };
      }
      return item;
    });

    const updatedTemplate: QCPekerjaan = {
      ...template,
      checklistItems: updatedItems,
      updatedAt: new Date().toISOString()
    };

    updatePekerjaanTemplate(updatedTemplate);
  };

  const handleAddItem = (e: React.FormEvent) => {
    e.preventDefault();
    if (!template || !newItemName.trim()) return;

    const newItem: PekerjaanChecklistTemplate = {
      id: `${template.id}-C${(template.checklistItems.length + 1).toString().padStart(2, '0')}`,
      name: newItemName.trim(),
      isActive: true
    };

    const updatedItems = [...template.checklistItems, newItem];
    const updatedTemplate: QCPekerjaan = {
      ...template,
      checklistItems: updatedItems,
      checklistCount: updatedItems.length,
      updatedAt: new Date().toISOString()
    };

    updatePekerjaanTemplate(updatedTemplate);
    setNewItemName('');
    setIsAddModalOpen(false);
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
      {/* Top Header Navigation */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <Button variant="outline" onClick={() => navigate('/data/qc-pekerjaan')} className="hover:bg-gray-50">
          ← Kembali ke Master Pekerjaan
        </Button>
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
              <div className="text-xs text-gray-400 font-semibold">ID Pekerjaan</div>
              <div className="text-sm font-bold text-gray-800">{template.id}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400 font-semibold">Nama Aktivitas</div>
              <div className="text-sm font-bold text-gray-800 leading-tight">{template.name}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400 font-semibold">Kategori Bidang</div>
              <div className="text-sm font-bold text-gray-800">{template.category}</div>
            </div>
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
            </div>
          </CardContent>
        </Card>

        {/* Checklist Item Parameters Area */}
        <div className="md:col-span-2 space-y-6">
          <Card title="Daftar Instruksi Checklist Uji">
            <div className="flex justify-between items-center px-6 py-3 border-b border-gray-100 bg-gray-50/50">
              <p className="text-xs text-gray-500">Langkah-langkah pemeriksaan fisik/teknis yang wajib divalidasi staf lapangan.</p>
              <Button
                onClick={() => setIsAddModalOpen(true)}
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

      {/* Add Item Modal */}
      <Modal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        title="Tambah Item Checklist Pekerjaan"
      >
        <form onSubmit={handleAddItem} className="space-y-4">
          <Input
            id="item-name"
            label="Deskripsi Instruksi / Pemeriksaan Lapangan"
            placeholder="Contoh: Pemasangan grounding rod sedalam 1.5 meter"
            value={newItemName}
            onChange={(e) => setNewItemName(e.target.value)}
            required
          />

          <div className="flex items-start gap-2 text-xs text-blue-700 bg-blue-50/50 p-3 rounded-lg border border-blue-200/50 leading-relaxed mt-2">
            <Info className="h-4 w-4 text-blue-500 flex-shrink-0 mt-0.5" />
            <span>Instruksi ini akan ditambahkan ke daftar checklist aktif yang wajib diverifikasi dan dijawab Ya/Tidak atau dilaporkan nilai aktualnya oleh staf.</span>
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-gray-100">
            <Button variant="outline" type="button" onClick={() => setIsAddModalOpen(false)}>
              Batal
            </Button>
            <Button variant="primary" type="submit" className="bg-[#006B5A] hover:bg-[#005244]" disabled={!newItemName.trim()}>
              Simpan Item
            </Button>
          </div>
        </form>
      </Modal>
    </PageTransition>
  );
};
