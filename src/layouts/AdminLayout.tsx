import React from 'react';
import { Outlet, Navigate, useLocation } from 'react-router-dom';
import { Sidebar } from '../components/layout/Sidebar';
import { Topbar } from '../components/layout/Topbar';
import { AnimatePresence } from 'framer-motion';

export const AdminLayout: React.FC = () => {
  const isLoggedIn = localStorage.getItem('isAdminLoggedIn') === 'true';
  const location = useLocation();

  if (!isLoggedIn) {
    return <Navigate to="/login" replace />;
  }

  const getPageTitle = (pathname: string) => {
    if (pathname === '/dashboard') return 'Dashboard Admin';
    if (pathname.startsWith('/laporan/')) return 'Detail Laporan QC';
    if (pathname === '/laporan') return 'Laporan Masuk';
    if (pathname === '/approval') return 'Approval Laporan';
    if (pathname.includes('/data/qc-material/')) return 'Detail Template QC Material';
    if (pathname === '/data/qc-material') return 'QC Material List';
    if (pathname === '/data/qc-pekerjaan') return 'QC Pekerjaan List';
    if (pathname === '/data') return 'Data Management';
    return 'QA Digitalization Admin';
  };

  const title = getPageTitle(location.pathname);

  return (
    <div className="min-h-screen bg-[#F7F9F8] no-scrollbar">
      <Sidebar />
      <div className="pl-[260px] no-scrollbar">
        <Topbar title={title} />
        <main className="pt-[94px] px-8 pb-12 min-h-screen overflow-hidden no-scrollbar">
          <AnimatePresence mode="wait">
            <div key={location.pathname}>
              <Outlet />
            </div>
          </AnimatePresence>
        </main>
      </div>
    </div>
  );
};
