import type { AdminUser, StaffWarehouseUser } from '../types/user';
import { STAFF_WAREHOUSE_ROLE } from '../utils/roles';

export const dummyAdmins: AdminUser[] = [
  {
    nik: '999001',
    name: 'Super Admin',
    role: 'Admin'
  }
];

export const dummyStaff: StaffWarehouseUser[] = [
  {
    nik: '120001',
    name: 'Ahmad Syarif',
    role: STAFF_WAREHOUSE_ROLE,
    siteName: 'Bekasi Site'
  },
  {
    nik: '120002',
    name: 'Budi Hartono',
    role: STAFF_WAREHOUSE_ROLE,
    siteName: 'Cikarang Plant'
  },
  {
    nik: '120003',
    name: 'Cecep Solihin',
    role: STAFF_WAREHOUSE_ROLE,
    siteName: 'Bandung Site'
  }
];
