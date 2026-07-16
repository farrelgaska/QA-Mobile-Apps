
import { createBrowserRouter, Navigate } from 'react-router-dom';
import { AuthLayout } from '../layouts/AuthLayout';
import { AdminLayout } from '../layouts/AdminLayout';
import { LoginPage } from '../pages/LoginPage';
import { DashboardPage } from '../pages/DashboardPage';
import { ReportsPage } from '../pages/ReportsPage';
import { ReportDetailPage } from '../pages/ReportDetailPage';
import { ApprovalPage } from '../pages/ApprovalPage';
import { DataManagementPage } from '../pages/DataManagementPage';
import { QCMaterialListPage } from '../pages/QCMaterialListPage';
import { QCMaterialDetailPage } from '../pages/QCMaterialDetailPage';
import { QCMaterialEditPage } from '../pages/QCMaterialEditPage';
import { QCPekerjaanListPage } from '../pages/QCPekerjaanListPage';
import { QCPekerjaanDetailPage } from '../pages/QCPekerjaanDetailPage';
import { QCPekerjaanEditPage } from '../pages/QCPekerjaanEditPage';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Navigate to="/login" replace />
  },
  {
    element: <AuthLayout />,
    children: [
      {
        path: 'login',
        element: <LoginPage />
      }
    ]
  },
  {
    element: <AdminLayout />,
    children: [
      {
        path: 'dashboard',
        element: <DashboardPage />
      },
      {
        path: 'laporan',
        element: <ReportsPage />
      },
      {
        path: 'laporan/:id',
        element: <ReportDetailPage />
      },
      {
        path: 'approval',
        element: <ApprovalPage />
      },
      {
        path: 'data',
        element: <DataManagementPage />
      },
      {
        path: 'data/qc-material',
        element: <QCMaterialListPage />
      },
      {
        path: 'data/qc-material/:id',
        element: <QCMaterialDetailPage />
      },
      {
        path: 'data/qc-material/:id/edit',
        element: <QCMaterialEditPage />
      },
      {
        path: 'data/qc-pekerjaan',
        element: <QCPekerjaanListPage />
      },
      {
        path: 'data/qc-pekerjaan/:id',
        element: <QCPekerjaanDetailPage />
      },
      {
        path: 'data/qc-pekerjaan/:id/edit',
        element: <QCPekerjaanEditPage />
      }
    ]
  },
  {
    path: '*',
    element: <Navigate to="/login" replace />
  }
]);
