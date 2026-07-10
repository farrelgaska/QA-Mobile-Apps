import React from 'react';
import { Outlet, Navigate } from 'react-router-dom';

export const AuthLayout: React.FC = () => {
  const isLoggedIn = localStorage.getItem('isAdminLoggedIn') === 'true';

  if (isLoggedIn) {
    return <Navigate to="/dashboard" replace />;
  }

  return (
    <div className="min-h-screen bg-[#F7F9F8] flex items-center justify-center p-4">
      <Outlet />
    </div>
  );
};
