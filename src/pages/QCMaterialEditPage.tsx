import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { fetchTemplates, patchTemplate } from '../services/reportApi';
import type { ApiTemplate } from '../services/reportApi';
import type { QCMaterial, MaterialStatus } from '../types/material';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { PageTransition } from '../components/layout/PageTransition';
import { ShieldAlert, Info } from 'lucide-react';

const mapApiToMaterial = (t: ApiTemplate): QCMaterial => ({
  id: t.id,
  name: t.name,
  category: t.category || '',
  standard: t.standardCode || '',
  checklistCount: t.checklistItems?.length || 0,
  status: t.isActive ? 'Aktif' : 'Nonaktif',
  updatedAt: t.updatedAt || new Date().toISOString(),
  checklistItems: (t.checklistItems || []).map((item) => ({
    id: item.id,
    name: item.parameterName,
    standardLabel: item.standardText,
    unit: item.unit || '',
    minVal: item.minValue ?? undefined,
    maxVal: item.maxValue ?? undefined,
    inputType: item.inputType,
    choiceOptions: item.choiceOptions,
    isRequired: item.isRequired,
    requiredPhoto: item.requiredPhoto,
    isActive: item.isActive,
    isCritical: item.isCritical,
    position: item.position
  }))
});

export const QCMaterialEditPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [template, setTemplate] = useState<QCMaterial | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Form Fields
  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [standard, setStandard] = useState('');
  const [status, setStatus] = useState<MaterialStatus>('Aktif');

  const loadData = async () => {
    if (!id) return;
    setIsLoading(true);
    setError(null);
    try {
      const all = await fetchTemplates();
      const foundApi = all.find(t => t.id === id && t.type === 'MATERIAL');
      if (foundApi) {
        const mapped = mapApiToMaterial(foundApi);
        setTemplate(mapped);
        setName(mapped.name);
        setCategory(mapped.category);
        setStandard(mapped.standard);
        setStatus(mapped.status);
      } else {
        setError('Template tidak ditemukan di server.');
      }
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal memuat template material.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [id]);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!template || !id) return;

    if (!name.trim()) {
      setError('Nama material tidak boleh kosong.');
      return;
    }
    if (!standard.trim()) {
      setError('Kode standar tidak boleh kosong.');
      return;
    }
    if (status === 'Aktif' && template.checklistItems.length === 0) {
      setError('Tambahkan minimal satu parameter sebelum template diaktifkan.');
      return;
    }

    setIsSaving(true);
    setError(null);
    try {
      const updatedTemplate: QCMaterial = {
        ...template,
        name,
        category,
        standard,
        status,
        updatedAt: new Date().toISOString()
      };

      await patchTemplate(id, {
        name: updatedTemplate.name,
        category: updatedTemplate.category,
        standardCode: updatedTemplate.standard,
        isActive: updatedTemplate.status === 'Aktif',
        updatedAt: updatedTemplate.updatedAt
      });

      navigate(`/data/qc-material/${id}`, {
        state: { successMessage: `Template "${name}" berhasil diperbarui.` }
      });
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal menyimpan perubahan.');
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <div className="p-3 text-sm text-blue-700 bg-blue-50 rounded-lg border border-blue-200 animate-pulse">
        Memuat data template...
      </div>
    );
  }

  if (error && !template) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-gray-500">
        <ShieldAlert className="h-10 w-10 text-rose-500 mb-3" />
        <p className="font-semibold">{error}</p>
        <Button variant="outline" className="mt-4" onClick={() => navigate('/data/qc-material')}>
          Kembali ke Master Material
        </Button>
      </div>
    );
  }

  if (!template) return null;

  return (
    <PageTransition className="space-y-6 max-w-2xl mx-auto px-1">
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <div>
          <h2 className="text-xl font-extrabold text-gray-900">Edit Metadata Template</h2>
          <p className="text-xs text-gray-500 mt-1">Ubah metadata dasar dari template material.</p>
        </div>
        <Button variant="outline" size="sm" onClick={() => navigate(`/data/qc-material/${id}`)} disabled={isSaving}>
          Batal
        </Button>
      </div>

      {error && (
        <div className="p-4 text-sm text-red-700 bg-red-50 rounded-lg border border-red-200">
          <strong>Error:</strong> {error}
        </div>
      )}

      <Card>
        <CardContent className="pt-6">
          <form onSubmit={handleSave} className="space-y-4">
            <Input
              id="edit-name"
              label="Nama Material"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              disabled={isSaving}
            />

            <Select
              id="edit-category"
              label="Kategori"
              value={category}
              onChange={(val) => setCategory(val)}
              options={[
                { value: 'Tiang Besi', label: 'Tiang Besi' },
                { value: 'Tiang Beton', label: 'Tiang Beton' }
              ]}
              disabled={isSaving}
            />

            <Input
              id="edit-standard"
              label="Kode Standar Perusahaan"
              value={standard}
              onChange={(e) => setStandard(e.target.value)}
              required
              disabled={isSaving}
            />

            <Select
              id="edit-status"
              label="Status Template"
              value={status}
              onChange={(val) => setStatus(val as MaterialStatus)}
              options={[
                { value: 'Aktif', label: 'Aktif' },
                { value: 'Nonaktif', label: 'Nonaktif' }
              ]}
              disabled={isSaving}
            />

            <div className="flex items-start gap-2 text-xs text-blue-700 bg-blue-50/50 p-3 rounded-lg border border-blue-200/50 leading-relaxed">
              <Info className="h-4 w-4 text-blue-500 flex-shrink-0 mt-0.5" />
              <span>Untuk mengubah parameter checklist uji, silakan gunakan menu kelola parameter di halaman detail spesifikasi template.</span>
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-gray-100">
              <Button variant="outline" type="button" onClick={() => navigate(`/data/qc-material/${id}`)} disabled={isSaving}>
                Batal
              </Button>
              <Button variant="primary" type="submit" className="bg-[#006B5A] hover:bg-[#005244]" disabled={isSaving}>
                {isSaving ? 'Menyimpan...' : 'Simpan Perubahan'}
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </PageTransition>
  );
};
export default QCMaterialEditPage;
