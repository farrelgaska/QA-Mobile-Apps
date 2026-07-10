import type { AdminUser, QAStaffUser } from '../types/user';

export const dummyAdmins: AdminUser[] = [
  {
    nik: '999001',
    name: 'Super Admin',
    role: 'Admin'
  }
];

export const dummyStaff: QAStaffUser[] = [
  {
    nik: '120001',
    name: 'Ahmad Syarif',
    role: 'QA Staff',
    siteName: 'Bekasi Site'
  },
  {
    nik: '120002',
    name: 'Budi Hartono',
    role: 'QA Staff',
    siteName: 'Cikarang Plant'
  },
  {
    nik: '120003',
    name: 'Cecep Solihin',
    role: 'QA Staff',
    siteName: 'Bandung Site'
  }
];
