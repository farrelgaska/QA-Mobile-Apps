import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import type { QCPekerjaan } from '../types/pekerjaan';
import { fetchTemplates, postTemplate, patchTemplate } from '../services/reportApi';
import type { ApiTemplate } from '../services/reportApi';
import { Card, CardContent } from '../components/ui/Card';
import { Table, TableHeader, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { PageTransition } from '../components/layout/PageTransition';
import { motion } from 'framer-motion';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Modal } from '../components/ui/Modal';
import { Search, Plus, Info } from 'lucide-react';

const mapApiToPekerjaan = (t: ApiTemplate): QCPekerjaan => ({
  id: t.id,
  name: t.name,
  category: t.category || '',
  segment: t.segment || 'construction',
  checklistCount: t.checklistItems?.length || 0,
  isActive: t.isActive,
  updatedAt: t.updatedAt || new Date().toISOString(),
  checklistItems: (t.checklistItems || []).map((item) => ({
    id: item.id,
    name: item.parameter_name || item.name || '',
    isActive: item.isActive !== undefined ? item.isActive : true
  }))
});

const mapPekerjaanToApi = (p: QCPekerjaan): ApiTemplate => ({
  id: p.id,
  type: 'WORK',
  name: p.name,
  formCode: `FORM-${p.id}`,
  category: p.category,
  standardCode: '',
  checklistItems: p.checklistItems.map(item => ({
    id: item.id,
    parameter_name: item.name,
    input_type: 'choice',
    standard_text: '',
    unit: '',
    is_required: true,
    name: item.name,
    isActive: item.isActive
  })),
  isActive: p.isActive,
  updatedAt: p.updatedAt || new Date().toISOString(),
  segment: p.segment
});

export const QCPekerjaanListPage: React.FC = () => {
  const navigate = useNavigate();
  const [pekerjaanList, setPekerjaanList] = useState<QCPekerjaan[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [segmentFilter, setSegmentFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  // Create Modal state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [newName, setNewName] = useState('');
  const [newCategory, setNewCategory] = useState('');
  const [newSegment, setNewSegment] = useState<'provisioning' | 'assurance' | 'construction'>('construction');

  const loadData = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const all = await fetchTemplates();
      const workTemplates = all
        .filter(t => t.type === 'WORK')
        .map(mapApiToPekerjaan);
      setPekerjaanList(workTemplates);
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal memuat template pekerjaan.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleToggleActive = async (id: string) => {
    const target = pekerjaanList.find(w => w.id === id);
    if (!target) return;

    const nextActive = !target.isActive;

    setIsLoading(true);
    setError(null);
    try {
      await patchTemplate(id, { isActive: nextActive });

      const updated = pekerjaanList.map(work => {
        if (work.id === id) {
          return { ...work, isActive: nextActive, updatedAt: new Date().toISOString() };
        }
        return work;
      });
      setPekerjaanList(updated);
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal mengubah status template.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCreateTemplate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newName || !newCategory) return;

    const newId = `WRK-${Date.now()}`;
    const newTemplate: QCPekerjaan = {
      id: newId,
      name: newName,
      category: newCategory,
      segment: newSegment,
      checklistCount: 0,
      isActive: true,
      updatedAt: new Date().toISOString(),
      checklistItems: []
    };

    setIsLoading(true);
    setError(null);
    try {
      const apiPayload = mapPekerjaanToApi(newTemplate);
      await postTemplate(apiPayload);

      setPekerjaanList(prev => [newTemplate, ...prev]);

      // Reset Form
      setNewName('');
      setNewCategory('');
      setNewSegment('construction');
      setIsCreateModalOpen(false);

      // Redirect to detail page
      navigate(`/data/qc-pekerjaan/${newId}`);
    } catch (e: any) {
      console.error(e);
      setError(e.message || 'Gagal membuat template baru.');
    } finally {
      setIsLoading(false);
    }
  };

  // Filtered data
  const filteredPekerjaan = pekerjaanList.filter(work => {
    const matchesSearch =
      work.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      work.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      work.category.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesSegment = segmentFilter === '' || work.segment === segmentFilter;
    const matchesStatus =
      statusFilter === '' ||
      (statusFilter === 'Aktif' && work.isActive) ||
      (statusFilter === 'Nonaktif' && !work.isActive);

    return matchesSearch && matchesSegment && matchesStatus;
  });

  const getSegmentBadgeColor = (seg: string): 'blue' | 'green' | 'yellow' | 'gray' => {
    switch (seg) {
      case 'construction': return 'blue';
      case 'provisioning': return 'green';
      case 'assurance': return 'yellow';
      default: return 'gray';
    }
  };

  return (
    <PageTransition className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-gray-800">Master Data QC Pekerjaan</h2>
          <p className="text-xs text-gray-500 mt-1">Kelola standar checklist teknis pemasangan, penarikan kabel, dan pemeliharaan site.</p>
        </div>
        <Button
          onClick={() => setIsCreateModalOpen(true)}
          className="bg-[#006B5A] hover:bg-[#005244] text-white"
          disabled={isLoading}
        >
          <Plus className="mr-2 h-4 w-4" />
          Tambah Template Baru
        </Button>
      </div>

      {error && (
        <div className="p-4 text-sm text-red-700 bg-red-50 rounded-lg border border-red-200">
          <strong>Error:</strong> {error}
        </div>
      )}

      {isLoading && (
        <div className="p-3 text-sm text-blue-700 bg-blue-50 rounded-lg border border-blue-200 animate-pulse">
          Menghubungkan ke API...
        </div>
      )}

      {/* Filter and Search controls */}
      <Card className="overflow-visible relative z-30">
        <CardContent className="pt-4 pb-4">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
            <div className="md:col-span-2">
              <Input
                id="search"
                label="Cari Template Pekerjaan"
                placeholder="Cari berdasarkan ID, nama pekerjaan, atau kategori..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                icon={<Search className="h-4 w-4 text-gray-400" />}
              />
            </div>
            <div>
              <Select
                id="segment"
                label="Segmen Pekerjaan"
                value={segmentFilter}
                onChange={(val) => setSegmentFilter(val)}
                options={[
                  { value: '', label: 'Semua Segmen' },
                  { value: 'construction', label: 'Construction' },
                  { value: 'provisioning', label: 'Provisioning' },
                  { value: 'assurance', label: 'Assurance' }
                ]}
              />
            </div>
            <div>
              <Select
                id="status"
                label="Status Keaktifan"
                value={statusFilter}
                onChange={(val) => setStatusFilter(val)}
                options={[
                  { value: '', label: 'Semua Status' },
                  { value: 'Aktif', label: 'Aktif' },
                  { value: 'Nonaktif', label: 'Nonaktif' }
                ]}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Table Card */}
      <Card className="relative z-0">
        <CardContent className="p-0">
          <motion.div
            key={`${segmentFilter}-${statusFilter}-${searchQuery}`}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-x-auto rounded-xl"
          >
            <Table>
              <TableHeader>
                <TableRow>
                  <TableCell isHeader>ID Pekerjaan</TableCell>
                  <TableCell isHeader>Nama Aktivitas</TableCell>
                  <TableCell isHeader>Segmen</TableCell>
                  <TableCell isHeader>Kategori Master</TableCell>
                  <TableCell isHeader className="text-center">Jumlah Checklist</TableCell>
                  <TableCell isHeader className="text-center">Status</TableCell>
                  <TableCell isHeader>Terakhir Diupdate</TableCell>
                  <TableCell isHeader className="text-center">Aksi</TableCell>
                </TableRow>
              </TableHeader>
              <TableBody>
                {isLoading && filteredPekerjaan.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={8} className="text-center py-12 text-gray-500 font-semibold">
                      Memuat data template dari API...
                    </TableCell>
                  </TableRow>
                ) : filteredPekerjaan.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={8} className="text-center py-12 text-gray-400">
                      Tidak ada kriteria pekerjaan yang cocok dengan kriteria pencarian.
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredPekerjaan.map((work) => (
                    <TableRow key={work.id} className="hover:bg-gray-50/50">
                      <TableCell className="font-bold text-gray-900">{work.id}</TableCell>
                      <TableCell className="font-semibold text-gray-800">{work.name}</TableCell>
                      <TableCell>
                        <Badge color={getSegmentBadgeColor(work.segment)} className="capitalize">
                          {work.segment}
                        </Badge>
                      </TableCell>
                      <TableCell className="font-medium text-gray-500">{work.category}</TableCell>
                      <TableCell className="text-center font-bold text-[#006B5A]">
                        {work.checklistItems ? work.checklistItems.length : work.checklistCount}
                      </TableCell>
                      <TableCell className="text-center">
                        <button
                          type="button"
                          onClick={() => handleToggleActive(work.id)}
                          className="focus:outline-none"
                          title="Klik untuk mengubah status keaktifan"
                        >
                          {work.isActive ? (
                            <span className="inline-flex items-center text-xs font-semibold text-emerald-700 bg-emerald-50 px-2 py-1 rounded-full border border-emerald-200 cursor-pointer">
                              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1 animate-pulse" />
                              Aktif
                            </span>
                          ) : (
                            <span className="inline-flex items-center text-xs font-semibold text-gray-500 bg-gray-50 px-2 py-1 rounded-full border border-gray-200 cursor-pointer">
                              <span className="w-1.5 h-1.5 rounded-full bg-gray-400 mr-1" />
                              Nonaktif
                            </span>
                          )}
                        </button>
                      </TableCell>
                      <TableCell className="text-xs text-gray-500 font-medium">
                        {new Date(work.updatedAt).toLocaleDateString('id-ID', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        })}
                      </TableCell>
                      <TableCell className="text-center">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => navigate(`/data/qc-pekerjaan/${work.id}`)}
                          className="hover:border-[#006B5A] hover:text-[#006B5A] text-xs"
                        >
                          Detail Checklist
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </motion.div>
        </CardContent>
      </Card>

      {/* Creation Modal */}
      <Modal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        title="Tambah Kategori Pekerjaan QC Baru"
      >
        <form onSubmit={handleCreateTemplate} className="space-y-4">
          <Input
            id="work-name"
            label="Nama Aktivitas Pekerjaan"
            placeholder="Contoh: Pemasangan ODP di Tiang"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            required
          />

          <Input
            id="work-category"
            label="Kategori / Bidang"
            placeholder="Contoh: Optical Access Network atau Sipil"
            value={newCategory}
            onChange={(e) => setNewCategory(e.target.value)}
            required
          />

          <Select
            id="work-segment"
            label="Segmen Layanan"
            value={newSegment}
            onChange={(val) => setNewSegment(val as 'provisioning' | 'assurance' | 'construction')}
            options={[
              { value: 'construction', label: 'Construction (Pembangunan)' },
              { value: 'provisioning', label: 'Provisioning (Pasang Baru)' },
              { value: 'assurance', label: 'Assurance (Gangguan)' }
            ]}
          />

          <div className="flex items-start gap-2 text-xs text-blue-700 bg-blue-50/50 p-3 rounded-lg border border-blue-200/50 leading-relaxed mt-2">
            <Info className="h-4 w-4 text-blue-500 flex-shrink-0 mt-0.5" />
            <span>Setelah menambahkan data dasar, Anda akan diarahkan ke halaman rincian checklist untuk mendefinisikan item-item instruksi pekerjaan.</span>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" type="button" onClick={() => setIsCreateModalOpen(false)}>
              Batal
            </Button>
            <Button variant="primary" type="submit" className="bg-[#006B5A] hover:bg-[#005244]" disabled={!newName || !newCategory}>
              Buat Template
            </Button>
          </div>
        </form>
      </Modal>
    </PageTransition>
  );
};
