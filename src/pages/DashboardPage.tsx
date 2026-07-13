import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useReports } from '../app/ReportsContext';
import { StatCard } from '../components/dashboard/StatCard';
import { ReportChart } from '../components/dashboard/ReportChart';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { ReportStatusBadge } from '../components/reports/ReportStatusBadge';
import {
  FileText,
  Clock,
  CheckCircle2,
  AlertTriangle,
  XCircle,
  ChevronRight,
  Layers,
  Briefcase,
  ClipboardList,
  TrendingUp,
} from 'lucide-react';

import { PageTransition } from '../components/layout/PageTransition';

export const DashboardPage: React.FC = () => {
  const navigate = useNavigate();
  const { reports } = useReports();


  // Compute statistics
  const totalReports = reports.length;
  const menungguReview = reports.filter(r => r.status === 'SUBMITTED').length;
  const disetujui = reports.filter(r => r.status === 'APPROVED').length;
  const perbaikan = reports.filter(r => r.status === 'NEEDS_FOLLOW_UP').length;
  const tidakLulus = reports.filter(r => r.standardResult === 'Tidak Lulus').length;

  // 5 most recent reports
  const recentReports = [...reports]
    .sort((a, b) => new Date(b.submittedAt).getTime() - new Date(a.submittedAt).getTime())
    .slice(0, 5);

  const greetingHour = new Date().getHours();
  const greeting =
    greetingHour < 12 ? 'Selamat Pagi' :
    greetingHour < 15 ? 'Selamat Siang' :
    greetingHour < 18 ? 'Selamat Sore' : 'Selamat Malam';

  const quickActions = [
    {
      id: 'review-laporan',
      label: 'Review Laporan Masuk',
      description: 'Tinjau & evaluasi laporan dari lapangan',
      icon: <ClipboardList className="h-5 w-5" />,
      path: '/approval',
      color: 'bg-[#E6F4F1] text-[#006B5A]',
      badge: menungguReview > 0 ? menungguReview : null,
    },
    {
      id: 'kelola-material',
      label: 'Kelola QC Material',
      description: 'Standar spesifikasi fisik material tiang',
      icon: <Layers className="h-5 w-5" />,
      path: '/data/qc-material',
      color: 'bg-blue-50 text-blue-600',
      badge: null,
    },
    {
      id: 'kelola-pekerjaan',
      label: 'Kelola QC Pekerjaan',
      description: 'Checklist teknis aktivitas pekerjaan',
      icon: <Briefcase className="h-5 w-5" />,
      path: '/data/qc-pekerjaan',
      color: 'bg-violet-50 text-violet-600',
      badge: null,
    },
  ];

  return (
    <PageTransition className="space-y-7 max-w-7xl mx-auto">
      {/* Greeting Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">
            {greeting}, <span className="text-[#006B5A]">Admin</span> 👋
          </h2>
          <p className="text-sm text-gray-500 mt-1">
            Berikut ringkasan aktivitas Quality Control hari ini —{' '}
            <span className="font-semibold text-gray-700">
              {new Date().toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}
            </span>
          </p>
        </div>
        {menungguReview > 0 && (
          <button
            onClick={() => navigate('/approval')}
            className="flex items-center gap-2 px-4 py-2.5 bg-amber-50 border border-amber-200 hover:bg-amber-100 text-amber-800 rounded-xl text-sm font-semibold transition-colors duration-150 group"
          >
            <span className="flex h-2 w-2 relative">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-amber-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-amber-500" />
            </span>
            {menungguReview} laporan menunggu review
            <ChevronRight className="h-4 w-4 group-hover:translate-x-0.5 transition-transform" />
          </button>
        )}
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-5 gap-4">
        <StatCard
          title="Total Laporan"
          value={totalReports}
          icon={<FileText className="h-6 w-6" />}
          tone="gray"
          description="Semua laporan QC"
        />
        <StatCard
          title="Menunggu Review"
          value={menungguReview}
          icon={<Clock className="h-6 w-6" />}
          tone="yellow"
          description="Perlu tindakan admin"
        />
        <StatCard
          title="Disetujui"
          value={disetujui}
          icon={<CheckCircle2 className="h-6 w-6" />}
          tone="green"
          description="Lulus standar QC"
        />
        <StatCard
          title="Perlu Tindak Lanjut"
          value={perbaikan}
          icon={<AlertTriangle className="h-6 w-6" />}
          tone="red"
          description="Diminta revisi"
        />
        <StatCard
          title="Tidak Lulus Standar"
          value={tidakLulus}
          icon={<XCircle className="h-6 w-6" />}
          tone="red"
          description="Hasil evaluasi gagal"
        />
      </div>

      {/* Chart + Quick Actions */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Chart Area */}
        <div className="lg:col-span-2">
          <Card>
            <div className="flex items-center justify-between px-6 pt-5 pb-2">
              <div>
                <h3 className="font-bold text-gray-800 text-base">Tren Laporan QC</h3>
                <p className="text-xs text-gray-400 mt-0.5">Grafik laporan masuk & disetujui per minggu</p>
              </div>
              <div className="flex items-center gap-4 text-xs text-gray-500">
                <span className="flex items-center gap-1.5">
                  <span className="inline-block h-2.5 w-2.5 rounded-sm bg-[#006B5A]" />
                  Total Laporan
                </span>
                <span className="flex items-center gap-1.5">
                  <span className="inline-block h-2.5 w-2.5 rounded-sm bg-emerald-400" />
                  Disetujui
                </span>
              </div>
            </div>
            <CardContent className="pt-0 pb-4">
              <ReportChart />
            </CardContent>
          </Card>
        </div>

        {/* Quick Actions */}
        <div className="space-y-4">
          <div>
            <h3 className="font-bold text-gray-800 text-base mb-1">Aksi Cepat</h3>
            <p className="text-xs text-gray-400">Navigasi langsung ke modul utama</p>
          </div>
          <div className="space-y-3">
            {quickActions.map((action) => (
              <button
                key={action.id}
                id={`quick-action-${action.id}`}
                onClick={() => navigate(action.path)}
                className="w-full text-left bg-white border border-gray-200/80 hover:border-[#006B5A]/30 hover:shadow-md rounded-xl px-4 py-3.5 transition-all duration-200 group flex items-center gap-4"
              >
                <div className={`h-10 w-10 rounded-xl flex items-center justify-center flex-shrink-0 transition-transform duration-200 group-hover:scale-105 ${action.color}`}>
                  {action.icon}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-semibold text-gray-800 truncate">{action.label}</span>
                    {action.badge !== null && (
                      <span className="flex-shrink-0 inline-flex items-center justify-center h-5 min-w-[20px] px-1.5 rounded-full bg-amber-500 text-white text-[10px] font-bold">
                        {action.badge}
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-gray-400 mt-0.5 truncate">{action.description}</p>
                </div>
                <ChevronRight className="h-4 w-4 text-gray-300 group-hover:text-[#006B5A] group-hover:translate-x-0.5 transition-all duration-150 flex-shrink-0" />
              </button>
            ))}
          </div>

          {/* Summary mini card */}
          <div className="bg-[#006B5A] rounded-xl p-4 text-white">
            <div className="flex items-center gap-2 mb-2">
              <TrendingUp className="h-4 w-4 text-emerald-300" />
              <span className="text-xs font-bold text-emerald-200 uppercase tracking-wider">Ringkasan</span>
            </div>
            <p className="text-2xl font-extrabold">
              {totalReports > 0 ? Math.round((disetujui / totalReports) * 100) : 0}%
            </p>
            <p className="text-xs text-emerald-200 mt-1">Tingkat persetujuan laporan QC</p>
            <div className="mt-3 h-1.5 bg-white/20 rounded-full overflow-hidden">
              <div
                className="h-full bg-emerald-400 rounded-full transition-all duration-700"
                style={{ width: `${totalReports > 0 ? Math.round((disetujui / totalReports) * 100) : 0}%` }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* Recent Reports */}
      <Card>
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div>
            <h3 className="font-bold text-gray-800 text-base">Laporan Terbaru</h3>
            <p className="text-xs text-gray-400 mt-0.5">5 laporan QC terkini dari lapangan</p>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() => navigate('/laporan')}
            className="text-xs hover:border-[#006B5A] hover:text-[#006B5A]"
          >
            Lihat Semua
            <ChevronRight className="h-3.5 w-3.5 ml-1" />
          </Button>
        </div>

        {/* Recent reports with inline status badges */}
        <div className="divide-y divide-gray-50">
          {recentReports.length === 0 ? (
            <div className="py-12 text-center text-sm text-gray-400 italic">Belum ada data laporan.</div>
          ) : (
            recentReports.map((report) => (
              <button
                key={report.id}
                id={`recent-report-${report.id}`}
                onClick={() => navigate(`/laporan/${report.id}`)}
                className="w-full flex items-center justify-between px-6 py-4 hover:bg-gray-50/60 transition-colors duration-150 text-left group"
              >
                <div className="flex items-start gap-4 flex-1 min-w-0">
                  <div className="flex-shrink-0 mt-0.5 h-9 w-9 rounded-lg bg-gray-100 flex items-center justify-center">
                    <FileText className="h-4 w-4 text-gray-400" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="text-xs font-bold text-gray-400 font-mono">{report.id}</span>
                      <span className="text-gray-300">·</span>
                      <span className="text-xs font-semibold text-gray-500 capitalize">
                        QC {report.type === 'material' ? 'Material' : 'Pekerjaan'}
                      </span>
                    </div>
                    <p className="text-sm font-semibold text-gray-800 truncate mt-0.5">{report.title}</p>
                    <p className="text-xs text-gray-400 mt-0.5">
                      Oleh {report.submittedBy} · {new Date(report.submittedAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' })}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-3 flex-shrink-0 ml-4">
                  <ReportStatusBadge status={report.status} />
                  <ChevronRight className="h-4 w-4 text-gray-300 group-hover:text-[#006B5A] group-hover:translate-x-0.5 transition-all" />
                </div>
              </button>
            ))
          )}
        </div>

        {recentReports.length > 0 && (
          <div className="px-6 py-3 border-t border-gray-50 bg-gray-50/30">
            <button
              onClick={() => navigate('/laporan')}
              className="text-xs font-semibold text-[#006B5A] hover:underline"
            >
              Tampilkan semua {totalReports} laporan →
            </button>
          </div>
        )}
      </Card>
    </PageTransition>
  );
};
