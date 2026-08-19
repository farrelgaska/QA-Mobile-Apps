import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  FileText,
  CheckSquare,
  Database,
  Layers,
  Briefcase,
  LogOut
} from 'lucide-react';
import { cn } from '../../utils/cn';

export const Sidebar: React.FC = () => {
  const location = useLocation();
  const currentPath = location.pathname;

  const menuItems = [
    { label: 'Dashboard', path: '/dashboard', icon: LayoutDashboard },
    { label: 'Laporan Masuk', path: '/laporan', icon: FileText },
    { label: 'Approval', path: '/approval', icon: CheckSquare },
    { label: 'Data Management', path: '/data', icon: Database },
    { label: 'QC Material', path: '/data/qc-material', icon: Layers },
    { label: 'QC Pekerjaan', path: '/data/qc-pekerjaan', icon: Briefcase },
  ];

  return (
    <aside className="w-[260px] bg-white border-r border-gray-200/80 h-screen flex flex-col fixed left-0 top-0 z-20">
      <div className="px-6 py-6 border-b border-gray-100 flex items-center gap-3">
        <img
          src="/assets/logo_qa.png"
          alt="QA Digitalization Logo"
          className="h-10 w-10 object-contain rounded-xl"
        />
        <div>
          <h1 className="font-bold text-gray-900 text-sm leading-none">QA Digitalization</h1>
          <span className="text-[10px] font-semibold text-gray-400 tracking-wider uppercase">Web Admin</span>
        </div>
      </div>

      <nav className="flex-1 px-4 py-6 space-y-1.5 overflow-y-auto">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive =
            item.path === '/data'
              ? currentPath === '/data'
              : currentPath === item.path ||
                (item.path !== '/dashboard' && currentPath.startsWith(item.path));

          return (
            <Link
              key={item.label}
              to={item.path}
              className={cn(
                'group flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-semibold transition-all duration-200 active:scale-[0.98]',
                isActive
                  ? 'bg-[#E6F4F1] text-[#006B5A]'
                  : 'text-gray-500 hover:bg-[#E6F4F1]/60 hover:text-gray-950'
              )}
            >
              <Icon
                className={cn(
                  'h-5 w-5 transition-colors duration-150',
                  isActive ? 'text-[#006B5A]' : 'text-gray-400 group-hover:text-gray-600'
                )}
              />
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-gray-100 bg-gray-50/50">
        <button
          onClick={() => {
            localStorage.removeItem('isAdminLoggedIn');
            localStorage.removeItem('qa_admin_auth');
            window.location.href = '/login';
          }}
          className="flex w-full items-center gap-3 px-4 py-3 text-sm font-semibold text-red-600 hover:bg-red-50 rounded-xl transition-all duration-150"
        >
          <LogOut className="h-5 w-5" />
          Keluar (Logout)
        </button>
      </div>
    </aside>
  );
};
