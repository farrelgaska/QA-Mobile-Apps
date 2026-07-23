import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { PageTransition } from '../components/layout/PageTransition';
import { dummyMaterials } from '../data/dummyMaterials';
import { dummyPekerjaan } from '../data/dummyPekerjaan';
import {
  Layers,
  Briefcase,
  ClipboardCheck,
  BarChart3,
  ChevronRight,
  CheckCircle,
  XCircle,
} from 'lucide-react';

interface DataModuleCard {
  id: string;
  icon: React.ReactNode;
  label: string;
  description: string;
  stats: { label: string; value: number | string; color?: string }[];
  actionLabel: string;
  actionPath?: string;
  actionDisabled?: boolean;
  iconBg: string;
  iconColor: string;
}

export const DataManagementPage: React.FC = () => {
  const navigate = useNavigate();

  const activeMaterials = dummyMaterials.filter(m => m.status === 'Aktif').length;
  const activePekerjaan = dummyPekerjaan.filter(p => p.isActive).length;

  const modules: DataModuleCard[] = [
    {
      id: 'qc-material',
      icon: <Layers className="h-7 w-7" />,
      label: 'QC Material',
      description: 'Template standar spesifikasi fisik material tiang besi dan tiang beton yang digunakan sebagai acuan pemeriksaan lapangan.',
      stats: [
        { label: 'Total Template', value: dummyMaterials.length },
        { label: 'Aktif', value: activeMaterials, color: 'text-emerald-600' },
        { label: 'Nonaktif', value: dummyMaterials.length - activeMaterials, color: 'text-gray-400' },
      ],
      actionLabel: 'Kelola QC Material',
      actionPath: '/data/qc-material',
      iconBg: 'bg-blue-50',
      iconColor: 'text-blue-600',
    },
    {
      id: 'qc-pekerjaan',
      icon: <Briefcase className="h-7 w-7" />,
      label: 'QC Pekerjaan',
      description: 'Template checklist aktivitas pekerjaan lapangan seperti pondasi, erection tiang, penarikan kabel, dan grounding system.',
      stats: [
        { label: 'Total Kategori', value: dummyPekerjaan.length },
        { label: 'Aktif', value: activePekerjaan, color: 'text-emerald-600' },
        { label: 'Nonaktif', value: dummyPekerjaan.length - activePekerjaan, color: 'text-gray-400' },
      ],
      actionLabel: 'Kelola QC Pekerjaan',
      actionPath: '/data/qc-pekerjaan',
      iconBg: 'bg-violet-50',
      iconColor: 'text-violet-600',
    },
    {
      id: 'template-checklist',
      icon: <ClipboardCheck className="h-7 w-7" />,
      label: 'Template Checklist',
      description: 'Kelola master template checklist yang digunakan oleh aplikasi mobile Staff Warehouse saat mengisi laporan pengujian di lapangan.',
      stats: [
        { label: 'Total Checklist', value: dummyMaterials.reduce((a, m) => a + m.checklistItems.length, 0) + dummyPekerjaan.reduce((a, p) => a + p.checklistItems.length, 0) },
        { label: 'Material', value: dummyMaterials.reduce((a, m) => a + m.checklistItems.length, 0) },
        { label: 'Pekerjaan', value: dummyPekerjaan.reduce((a, p) => a + p.checklistItems.length, 0) },
      ],
      actionLabel: 'Lihat Template (Coming Soon)',
      actionDisabled: true,
      iconBg: 'bg-amber-50',
      iconColor: 'text-amber-600',
    },
    {
      id: 'standar-evaluasi',
      icon: <BarChart3 className="h-7 w-7" />,
      label: 'Standar Evaluasi',
      description: 'Konfigurasi batas toleransi penilaian, aturan auto-scoring, dan ketentuan kelulusan laporan QC berdasarkan regulasi SPLN/SNI.',
      stats: [
        { label: 'Total Aturan', value: '12' },
        { label: 'Material', value: '7' },
        { label: 'Pekerjaan', value: '5' },
      ],
      actionLabel: 'Kelola Standar (Coming Soon)',
      actionDisabled: true,
      iconBg: 'bg-[#E6F4F1]',
      iconColor: 'text-[#006B5A]',
    },
  ];

  return (
    <PageTransition className="space-y-7 max-w-6xl mx-auto">
      {/* Page Header */}
      <div>
        <h2 className="text-xl font-extrabold text-gray-900">Data Management</h2>
        <p className="text-xs text-gray-500 mt-1">
          Pusat konfigurasi standar QC — kelola template material, pekerjaan, checklist, dan aturan evaluasi.
        </p>
      </div>

      {/* Summary bar */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: 'Template Material', value: dummyMaterials.length, color: 'border-blue-200 bg-blue-50 text-blue-700' },
          { label: 'Template Pekerjaan', value: dummyPekerjaan.length, color: 'border-violet-200 bg-violet-50 text-violet-700' },
          { label: 'Total Checklist Item', value: dummyMaterials.reduce((a, m) => a + m.checklistItems.length, 0) + dummyPekerjaan.reduce((a, p) => a + p.checklistItems.length, 0), color: 'border-amber-200 bg-amber-50 text-amber-700' },
          { label: 'Template Aktif', value: activeMaterials + activePekerjaan, color: 'border-emerald-200 bg-emerald-50 text-emerald-700' },
        ].map((item) => (
          <div key={item.label} className={`flex flex-col items-center justify-center p-4 rounded-xl border ${item.color}`}>
            <div className="text-2xl font-extrabold">{item.value}</div>
            <div className="text-xs font-semibold mt-1 opacity-80">{item.label}</div>
          </div>
        ))}
      </div>

      {/* Module Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {modules.map((mod) => (
          <div
            key={mod.id}
            className="bg-white border border-gray-200/80 rounded-2xl shadow-sm hover:shadow-md transition-all duration-200 flex flex-col overflow-hidden"
          >
            {/* Card Header */}
            <div className="p-6 flex items-start gap-4">
              <div className={`h-14 w-14 rounded-xl flex items-center justify-center flex-shrink-0 ${mod.iconBg} ${mod.iconColor}`}>
                {mod.icon}
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="font-bold text-gray-900 text-base">{mod.label}</h3>
                <p className="text-xs text-gray-500 leading-relaxed mt-1">{mod.description}</p>
              </div>
            </div>

            {/* Stats row */}
            <div className="px-6 pb-4 grid grid-cols-3 gap-2">
              {mod.stats.map((stat) => (
                <div key={stat.label} className="bg-gray-50 border border-gray-100 rounded-xl p-3 text-center">
                  <div className={`text-xl font-extrabold ${stat.color ?? 'text-gray-800'}`}>{stat.value}</div>
                  <div className="text-[10px] font-semibold text-gray-400 mt-0.5">{stat.label}</div>
                </div>
              ))}
            </div>

            {/* Action */}
            <div className="px-6 pb-6 mt-auto">
              <Button
                id={`manage-${mod.id}`}
                className={`w-full flex items-center justify-center gap-2 ${
                  mod.actionDisabled
                    ? 'opacity-50 cursor-not-allowed bg-gray-100 text-gray-500 border border-gray-200 hover:bg-gray-100'
                    : 'bg-[#006B5A] hover:bg-[#005244] text-white shadow-sm shadow-[#006B5A]/20'
                }`}
                onClick={() => !mod.actionDisabled && mod.actionPath && navigate(mod.actionPath)}
                disabled={mod.actionDisabled}
              >
                {mod.actionLabel}
                {!mod.actionDisabled && <ChevronRight className="h-4 w-4" />}
              </Button>
            </div>
          </div>
        ))}
      </div>

      {/* Quick status overview */}
      <Card title="Status Keaktifan Template">
        <CardContent className="pt-3">
          <div className="space-y-3">
            {[...dummyMaterials.map(m => ({ id: m.id, name: m.name, type: 'Material', isActive: m.status === 'Aktif', category: m.category })),
              ...dummyPekerjaan.map(p => ({ id: p.id, name: p.name, type: 'Pekerjaan', isActive: p.isActive, category: p.category }))
            ].slice(0, 6).map((item) => (
              <div key={item.id} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
                <div className="flex items-center gap-3">
                  <div className={`h-2 w-2 rounded-full flex-shrink-0 ${item.isActive ? 'bg-emerald-500' : 'bg-gray-300'}`} />
                  <div>
                    <span className="text-sm font-semibold text-gray-700">{item.name}</span>
                    <span className="text-xs text-gray-400 ml-2">({item.type} · {item.category})</span>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs text-gray-400">{item.id}</span>
                  {item.isActive
                    ? <CheckCircle className="h-4 w-4 text-emerald-500" />
                    : <XCircle className="h-4 w-4 text-gray-300" />
                  }
                </div>
              </div>
            ))}
          </div>
          <p className="text-xs text-gray-400 mt-3">Menampilkan 6 dari {dummyMaterials.length + dummyPekerjaan.length} template terdaftar.</p>
        </CardContent>
      </Card>
    </PageTransition>
  );
};
