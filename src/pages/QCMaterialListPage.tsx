import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import type { QCMaterial, MaterialStatus } from '../types/material';
import { dummyMaterials } from '../data/dummyMaterials';
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

export const QCMaterialListPage: React.FC = () => {
  const navigate = useNavigate();
  const [materials, setMaterials] = useState<QCMaterial[]>([]);

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  // Create Modal state
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [newName, setNewName] = useState('');
  const [newCategory, setNewCategory] = useState('Tiang Besi');
  const [newStandard, setNewStandard] = useState('');

  useEffect(() => {
    const stored = localStorage.getItem('materials');
    if (stored) {
      setMaterials(JSON.parse(stored));
    } else {
      localStorage.setItem('materials', JSON.stringify(dummyMaterials));
      setMaterials(dummyMaterials);
    }
  }, []);

  const handleToggleStatus = (id: string) => {
    const updated = materials.map(mat => {
      if (mat.id === id) {
        const nextStatus: MaterialStatus = mat.status === 'Aktif' ? 'Nonaktif' : 'Aktif';
        return { ...mat, status: nextStatus, updatedAt: new Date().toISOString() };
      }
      return mat;
    });
    setMaterials(updated);
    localStorage.setItem('materials', JSON.stringify(updated));
  };

  const handleCreateTemplate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newName || !newStandard) return;

    const newId = `MAT-0${materials.length + 1}`;
    const newTemplate: QCMaterial = {
      id: newId,
      name: newName,
      category: newCategory,
      standard: newStandard,
      checklistCount: 0,
      status: 'Aktif',
      updatedAt: new Date().toISOString(),
      checklistItems: []
    };

    const updated = [newTemplate, ...materials];
    setMaterials(updated);
    localStorage.setItem('materials', JSON.stringify(updated));

    // Reset fields
    setNewName('');
    setNewStandard('');
    setIsCreateModalOpen(false);

    // Redirect to detail page to let them add checklist items
    navigate(`/data/qc-material/${newId}`);
  };

  // Filtered data
  const filteredMaterials = materials.filter(mat => {
    const matchesSearch =
      mat.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      mat.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      mat.standard.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesCategory = categoryFilter === '' || mat.category === categoryFilter;
    const matchesStatus = statusFilter === '' || mat.status === statusFilter;

    return matchesSearch && matchesCategory && matchesStatus;
  });

  const categories = Array.from(new Set(materials.map(m => m.category)));

  return (
    <PageTransition className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-gray-800">Master Data QC Material</h2>
          <p className="text-xs text-gray-500 mt-1">Kelola standardisasi spesifikasi fisik material tiang beton &amp; tiang besi.</p>
        </div>
        <Button
          onClick={() => setIsCreateModalOpen(true)}
          className="bg-[#006B5A] hover:bg-[#005244] text-white"
        >
          <Plus className="mr-2 h-4 w-4" />
          Tambah Template Baru
        </Button>
      </div>

      {/* Filter and Search controls */}
      <Card className="overflow-visible relative z-30">
        <CardContent className="pt-4 pb-4">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 items-end">
            <div className="md:col-span-2">
              <Input
                id="search"
                label="Cari Template Material"
                placeholder="Cari berdasarkan ID, nama tiang, atau standard..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                icon={<Search className="h-4 w-4 text-gray-400" />}
              />
            </div>
            <div>
              <Select
                id="category"
                label="Kategori"
                value={categoryFilter}
                onChange={(val) => setCategoryFilter(val)}
                options={[
                  { value: '', label: 'Semua Kategori' },
                  ...categories.map(c => ({ value: c, label: c }))
                ]}
              />
            </div>
            <div>
              <Select
                id="status"
                label="Status"
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
            key={`${categoryFilter}-${statusFilter}-${searchQuery}`}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2 }}
            className="overflow-x-auto rounded-xl"
          >
            <Table>
              <TableHeader>
                <TableRow>
                  <TableCell isHeader>ID Material</TableCell>
                  <TableCell isHeader>Nama Template</TableCell>
                  <TableCell isHeader className="text-center">Kategori</TableCell>
                  <TableCell isHeader>Kode Standard Perusahaan</TableCell>
                  <TableCell isHeader className="text-center">Jumlah Parameter</TableCell>
                  <TableCell isHeader className="text-center">Status Standar</TableCell>
                  <TableCell isHeader>Terakhir Diupdate</TableCell>
                  <TableCell isHeader className="text-center">Aksi</TableCell>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredMaterials.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={8} className="text-center py-12 text-gray-400">
                      Tidak ada template material yang cocok dengan kriteria pencarian.
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredMaterials.map((mat) => (
                    <TableRow key={mat.id} className="hover:bg-gray-50/50">
                      <TableCell className="font-bold text-gray-900">{mat.id}</TableCell>
                      <TableCell className="font-semibold text-gray-800">{mat.name}</TableCell>
                      <TableCell className="text-center align-middle">
                        <div className="flex items-center justify-center">
                          <Badge 
                            color={mat.category.includes('Besi') ? 'blue' : 'orange'}
                            className="min-w-[90px] text-center"
                          >
                            {mat.category}
                          </Badge>
                        </div>
                      </TableCell>
                      <TableCell className="font-medium text-gray-500">{mat.standard}</TableCell>
                      <TableCell className="text-center font-bold text-[#006B5A]">
                        {mat.checklistItems ? mat.checklistItems.length : mat.checklistCount}
                      </TableCell>
                      <TableCell className="text-center">
                        <button
                          type="button"
                          onClick={() => handleToggleStatus(mat.id)}
                          className="focus:outline-none inline-flex items-center gap-1.5"
                          title="Klik untuk mengubah status keaktifan"
                        >
                          {mat.status === 'Aktif' ? (
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
                        {new Date(mat.updatedAt).toLocaleDateString('id-ID', {
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
                          onClick={() => navigate(`/data/qc-material/${mat.id}`)}
                          className="hover:border-[#006B5A] hover:text-[#006B5A] text-xs"
                        >
                          Detail Spesifikasi
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
        title="Tambah Template Standar Material Baru"
      >
        <form onSubmit={handleCreateTemplate} className="space-y-4">
          <Input
            id="template-name"
            label="Nama Material"
            placeholder="Contoh: Tiang Besi 12 Meter"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            required
          />

          <Select
            id="template-category"
            label="Kategori"
            value={newCategory}
            onChange={(val) => setNewCategory(val)}
            options={[
              { value: 'Tiang Besi', label: 'Tiang Besi' },
              { value: 'Tiang Beton', label: 'Tiang Beton' }
            ]}
          />

          <Input
            id="template-standard"
            label="Kode Standar Perusahaan"
            placeholder="Contoh: SPLN T3.001-3:2025"
            value={newStandard}
            onChange={(e) => setNewStandard(e.target.value)}
            required
          />

          <div className="flex items-start gap-2 text-xs text-blue-700 bg-blue-50/50 p-3 rounded-lg border border-blue-200/50 leading-relaxed mt-2">
            <Info className="h-4 w-4 text-blue-500 flex-shrink-0 mt-0.5" />
            <span>Setelah menambahkan template dasar, Anda akan diarahkan ke halaman detail spesifikasi untuk mendefinisikan parameter checklist uji.</span>
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" type="button" onClick={() => setIsCreateModalOpen(false)}>
              Batal
            </Button>
            <Button variant="primary" type="submit" className="bg-[#006B5A] hover:bg-[#005244]" disabled={!newName || !newStandard}>
              Buat Template
            </Button>
          </div>
        </form>
      </Modal>
    </PageTransition>
  );
};
