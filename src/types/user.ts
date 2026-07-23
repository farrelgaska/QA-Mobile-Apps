import type { StaffWarehouseRoleValue } from '../utils/roles';

export interface Site {
  id: string;
  name: string;
  area: string;
  zona: string;
}

export interface AdminUser {
  nik: string;
  name: string;
  role: 'ADMIN' | 'Admin';
}

export interface StaffWarehouseUser {
  nik: string;
  name: string;
  role: StaffWarehouseRoleValue;
  siteName?: string;
}
