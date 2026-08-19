import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Info, ShieldAlert } from 'lucide-react';
import { Button } from '../components/ui/Button';
import { Card, CardContent } from '../components/ui/Card';
import { Input } from '../components/ui/Input';
import { PageTransition } from '../components/layout/PageTransition';
import { fetchTemplate, patchTemplate } from '../services/reportApi';
import type { ApiTemplate } from '../services/reportApi';

export const QCPekerjaanEditPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [template, setTemplate] = useState<ApiTemplate | null>(null);
  const [formCode, setFormCode] = useState('');
  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [description, setDescription] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    let isCurrent = true;
    setIsLoading(true);
    setError(null);
    fetchTemplate(id)
      .then(result => {
        if (!isCurrent) return;
        if (result.type !== 'WORK') throw new Error('Template pekerjaan tidak ditemukan.');
        setTemplate(result);
        setFormCode(result.formCode);
        setName(result.name);
        setCategory(result.category);
        setDescription(result.description ?? '');
      })
      .catch((cause: unknown) => {
        if (isCurrent) setError(cause instanceof Error ? cause.message : 'Gagal memuat template pekerjaan.');
      })
      .finally(() => { if (isCurrent) setIsLoading(false); });
    return () => { isCurrent = false; };
  }, [id]);

  const handleSave = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!id || !template) return;
    if (!formCode.trim() || !name.trim() || !category.trim()) {
      setError('Kode pekerjaan, nama aktivitas, dan kategori bidang wajib diisi.');
      return;
    }

    setIsSaving(true);
    setError(null);
    try {
      await patchTemplate(id, {
        formCode: formCode.trim(),
        name: name.trim(),
        category: category.trim(),
        description: description.trim(),
      });
      const refreshed = await fetchTemplate(id);
      navigate(`/data/qc-pekerjaan/${id}`, {
        state: { successMessage: `Template "${refreshed.name}" berhasil diperbarui.` },
      });
    } catch (cause: unknown) {
      setError(cause instanceof Error ? cause.message : 'Gagal menyimpan perubahan.');
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return <div className="p-3 text-sm text-blue-700 bg-blue-50 rounded-lg border border-blue-200 animate-pulse">Memuat data template...</div>;
  }

  if (!template) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-gray-500">
        <ShieldAlert className="h-10 w-10 text-rose-500 mb-3" />
        <p className="font-semibold">{error || 'Template Pekerjaan tidak ditemukan.'}</p>
        <Button variant="outline" className="mt-4" onClick={() => navigate('/data/qc-pekerjaan')}>Kembali ke Master Pekerjaan</Button>
      </div>
    );
  }

  return (
    <PageTransition className="space-y-6 max-w-2xl mx-auto px-1">
      <div className="flex items-center justify-between border-b border-gray-200 pb-4">
        <div>
          <h2 className="text-xl font-extrabold text-gray-900">Edit Metadata Template</h2>
          <p className="text-xs text-gray-500 mt-1">Ubah metadata dasar template pekerjaan.</p>
        </div>
        <Button variant="outline" size="sm" onClick={() => navigate(`/data/qc-pekerjaan/${id}`)} disabled={isSaving}>Batal</Button>
      </div>

      {error && <div className="p-4 text-sm text-red-700 bg-red-50 rounded-lg border border-red-200"><strong>Error:</strong> {error}</div>}

      <Card>
        <CardContent className="pt-6">
          <form onSubmit={handleSave} className="space-y-4">
            <Input id="work-form-code" label="ID/Kode Pekerjaan" value={formCode} onChange={event => setFormCode(event.target.value)} required disabled={isSaving} />
            <Input id="work-name" label="Nama Aktivitas" value={name} onChange={event => setName(event.target.value)} required disabled={isSaving} />
            <Input id="work-category" label="Kategori Bidang" value={category} onChange={event => setCategory(event.target.value)} required disabled={isSaving} />
            <Input id="work-description" label="Deskripsi" value={description} onChange={event => setDescription(event.target.value)} disabled={isSaving} />

            <div className="flex items-start gap-2 text-xs text-blue-700 bg-blue-50/50 p-3 rounded-lg border border-blue-200/50 leading-relaxed">
              <Info className="h-4 w-4 text-blue-500 flex-shrink-0 mt-0.5" />
              <span>ID teknis <strong>{template.id}</strong> bersifat tetap. Parameter checklist dikelola dari halaman detail.</span>
            </div>

            <div className="flex justify-end gap-2 pt-4 border-t border-gray-100">
              <Button variant="outline" type="button" onClick={() => navigate(`/data/qc-pekerjaan/${id}`)} disabled={isSaving}>Batal</Button>
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

export default QCPekerjaanEditPage;
