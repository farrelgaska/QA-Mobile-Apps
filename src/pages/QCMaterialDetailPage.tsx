import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import type { QCMaterial, MaterialChecklistTemplate } from '../types/material';
import { dummyMaterials } from '../data/dummyMaterials';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { PageTransition } from '../components/layout/PageTransition';
import { Table, TableHeader, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Input } from '../components/ui/Input';
import { Modal } from '../components/ui/Modal';
import { Badge } from '../components/ui/Badge';
import { Plus, Trash2, ShieldAlert } from 'lucide-react';

export const QCMaterialDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [materials, setMaterials] = useState<QCMaterial[]>([]);
  const [template, setTemplate] = useState<QCMaterial | null>(null);

  // Modal State
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);

  // New Checklist Form fields
  const [paramName, setParamName] = useState('');
  const [standardLabel, setStandardLabel] = useState('');
  const [unit, setUnit] = useState('mm');
  const [minVal, setMinVal] = useState('');
  const [maxVal, setMaxVal] = useState('');
  const [requiredPhoto, setRequiredPhoto] = useState<boolean>(false);

  useEffect(() => {
    const stored = localStorage.getItem('materials');
    const list: QCMaterial[] = stored ? JSON.parse(stored) : dummyMaterials;
    setMaterials(list);

    const found = list.find(m => m.id === id);
    if (found) {
      setTemplate(found);
    }
  }, [id]);

  const updateMaterialTemplate = (updatedTemplate: QCMaterial) => {
    const updatedList = materials.map(m => m.id === updatedTemplate.id ? updatedTemplate : m);
    setMaterials(updatedList);
    setTemplate(updatedTemplate);
    localStorage.setItem('materials', JSON.stringify(updatedList));
  };

  const handleDeleteItem = (itemId: string) => {
    if (!template) return;

    const updatedItems = template.checklistItems.filter(item => item.id !== itemId);
    const updatedTemplate: QCMaterial = {
      ...template,
      checklistItems: updatedItems,
      checklistCount: updatedItems.length,
      updatedAt: new Date().toISOString()
    };

    updateMaterialTemplate(updatedTemplate);
  };

  const handleAddParameter = (e: React.FormEvent) => {
    e.preventDefault();
    if (!template || !paramName || !standardLabel) return;

    const newItem: MaterialChecklistTemplate = {
      id: `${template.id}-C${(template.checklistItems.length + 1).toString().padStart(2, '0')}`,
      name: paramName,
      standardLabel,
      unit,
      minVal: minVal ? parseFloat(minVal) : undefined,
      maxVal: maxVal ? parseFloat(maxVal) : undefined,
      requiredPhoto
    };

    const updatedItems = [...template.checklistItems, newItem];
    const updatedTemplate: QCMaterial = {
      ...template,
      checklistItems: updatedItems,
      checklistCount: updatedItems.length,
      updatedAt: new Date().toISOString()
    };

    updateMaterialTemplate(updatedTemplate);

    // Reset Form
    setParamName('');
    setStandardLabel('');
    setUnit('mm');
    setMinVal('');
    setMaxVal('');
    setRequiredPhoto(false);
    setIsAddModalOpen(false);
  };

  if (!template) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-gray-500">
        <ShieldAlert className="h-10 w-10 text-rose-500 mb-3" />
        <p className="font-semibold">Template QC Material tidak ditemukan.</p>
        <Button variant="outline" className="mt-4" onClick={() => navigate('/data/qc-material')}>
          Kembali ke Daftar
        </Button>
      </div>
    );
  }

  return (
    <PageTransition className="space-y-6 max-w-7xl mx-auto px-1">
      {/* Top Header Navigation */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Button variant="outline" onClick={() => navigate('/data/qc-material')} className="hover:bg-gray-50">
            ← Kembali ke Master Material
          </Button>
          <Button 
            variant="outline" 
            size="sm" 
            onClick={() => alert('Fitur Edit Metadata Template (Dummy)')}
            className="text-xs text-gray-600 hover:text-gray-900"
          >
            Edit Template
          </Button>
        </div>
        <div className="flex items-center gap-2">
          <Badge color={template.category.includes('Besi') ? 'blue' : 'orange'} className="text-xs uppercase tracking-wider font-semibold">
            {template.category}
          </Badge>
          <span className="text-gray-300">|</span>
          <span className="text-xs text-gray-400 font-medium">Diupdate: {new Date(template.updatedAt).toLocaleDateString('id-ID')}</span>
        </div>
      </div>

      {/* Metadata Detail */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card title="Detail Spesifikasi Standar" className="md:col-span-1">
          <CardContent className="space-y-4 pt-2">
            <div>
              <div className="text-xs text-gray-400 font-semibold">ID Material</div>
              <div className="text-sm font-bold text-gray-800">{template.id}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400 font-semibold">Nama Template</div>
              <div className="text-sm font-bold text-gray-800 leading-tight">{template.name}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400 font-semibold">Kode Standard Perusahaan</div>
              <div className="text-sm font-bold text-gray-800">{template.standard}</div>
            </div>
            <div>
              <div className="text-xs text-gray-400 font-semibold">Status Uji Lapangan</div>
              <div className="mt-1">
                {template.status === 'Aktif' ? (
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

        {/* Checklist Parameters Area */}
        <div className="md:col-span-2 space-y-6">
          <Card title="Daftar Parameter Checklist Uji">
            <div className="flex justify-between items-center px-6 py-3 border-b border-gray-100 bg-gray-50/50">
              <p className="text-xs text-gray-500">Kriteria verifikasi fisik material yang harus diisi oleh QA Staff di lapangan.</p>
              <Button
                onClick={() => setIsAddModalOpen(true)}
                size="sm"
                className="bg-[#006B5A] hover:bg-[#005244] text-white flex-shrink-0 ml-4"
              >
                <Plus className="mr-1.5 h-4 w-4" />
                Tambah Parameter
              </Button>
            </div>
            <CardContent className="p-0">
              <div className="overflow-x-auto rounded-b-xl border-t border-gray-150">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableCell isHeader className="w-12 text-center">No</TableCell>
                      <TableCell isHeader>Nama Parameter</TableCell>
                      <TableCell isHeader className="text-center">Tipe Input</TableCell>
                      <TableCell isHeader>Label Acuan Standard</TableCell>
                      <TableCell isHeader className="text-center">Toleransi</TableCell>
                      <TableCell isHeader className="text-center">Wajib Foto</TableCell>
                      <TableCell isHeader className="text-center">Status</TableCell>
                      <TableCell isHeader className="text-center">Aksi</TableCell>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {!template.checklistItems || template.checklistItems.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={8} className="text-center py-12 text-gray-400 italic">
                          Belum ada kriteria uji. Klik "Tambah Parameter" untuk membuat kriteria baru.
                        </TableCell>
                      </TableRow>
                    ) : (
                      template.checklistItems.map((item, idx) => (
                        <TableRow key={item.id} className="hover:bg-gray-50/50">
                          <TableCell className="text-center text-gray-400 font-medium">{idx + 1}</TableCell>
                          <TableCell className="font-semibold text-gray-800">{item.name}</TableCell>
                          <TableCell className="text-center">
                            <Badge color={item.unit ? 'blue' : 'gray'} className="text-[10px]">
                              {item.unit ? 'Angka / Ukuran' : 'Pilihan Visual'}
                            </Badge>
                          </TableCell>
                          <TableCell className="font-medium text-gray-500">
                            {item.standardLabel}
                          </TableCell>
                          <TableCell className="text-center text-xs text-gray-500">
                            {item.minVal !== undefined || item.maxVal !== undefined ? (
                              <div className="font-semibold">
                                {item.minVal !== undefined && `Min: ${item.minVal}`}
                                {item.minVal !== undefined && item.maxVal !== undefined && ' | '}
                                {item.maxVal !== undefined && `Max: ${item.maxVal}`}
                                {item.unit && ` ${item.unit}`}
                              </div>
                            ) : (
                              <span className="text-gray-400 italic">N/A</span>
                            )}
                          </TableCell>
                          <TableCell className="text-center">
                            {item.requiredPhoto ? (
                              <span className="inline-flex items-center text-[10px] font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded border border-amber-200">
                                YA
                              </span>
                            ) : (
                              <span className="text-xs text-gray-400">Tidak</span>
                            )}
                          </TableCell>
                          <TableCell className="text-center">
                            <span className="inline-flex items-center text-[10px] font-semibold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-100">
                              AKTIF
                            </span>
                          </TableCell>
                          <TableCell className="text-center">
                            <button
                              type="button"
                              onClick={() => handleDeleteItem(item.id)}
                              className="text-rose-500 hover:text-rose-700 p-1.5 rounded-lg hover:bg-rose-50 transition-colors"
                              title="Hapus Parameter"
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

      {/* Add Parameter Modal */}
      <Modal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        title="Tambah Parameter Checklist QC"
      >
        <form onSubmit={handleAddParameter} className="space-y-4">
          <Input
            id="param-name"
            label="Nama Parameter / Karakteristik Fisik"
            placeholder="Contoh: Ketebalan Dinding Bawah"
            value={paramName}
            onChange={(e) => setParamName(e.target.value)}
            required
          />

          <Input
            id="standard-label"
            label="Uraian Batas Acuan Standar"
            placeholder="Contoh: min 4.2 mm atau 120 - 130 micron"
            value={standardLabel}
            onChange={(e) => setStandardLabel(e.target.value)}
            required
          />

          <div className="grid grid-cols-3 gap-3">
            <div>
              <Input
                id="unit"
                label="Satuan Ukur"
                placeholder="mm, micron"
                value={unit}
                onChange={(e) => setUnit(e.target.value)}
              />
            </div>
            <div>
              <Input
                id="min-val"
                label="Toleransi Min"
                type="number"
                step="any"
                placeholder="min"
                value={minVal}
                onChange={(e) => setMinVal(e.target.value)}
              />
            </div>
            <div>
              <Input
                id="max-val"
                label="Toleransi Max"
                type="number"
                step="any"
                placeholder="max"
                value={maxVal}
                onChange={(e) => setMaxVal(e.target.value)}
              />
            </div>
          </div>

          <div className="flex items-center gap-2 py-2">
            <input
              id="req-photo"
              type="checkbox"
              checked={requiredPhoto}
              onChange={(e) => setRequiredPhoto(e.target.checked)}
              className="h-4 w-4 text-[#006B5A] border-gray-300 rounded focus:ring-[#006B5A]"
            />
            <label htmlFor="req-photo" className="text-xs font-semibold text-gray-700 select-none cursor-pointer">
              Wajib Unggah Foto Bukti Lapangan
            </label>
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-gray-100">
            <Button variant="outline" type="button" onClick={() => setIsAddModalOpen(false)}>
              Batal
            </Button>
            <Button variant="primary" type="submit" className="bg-[#006B5A] hover:bg-[#005244]" disabled={!paramName || !standardLabel}>
              Simpan Parameter
            </Button>
          </div>
        </form>
      </Modal>
    </PageTransition>
  );
};
