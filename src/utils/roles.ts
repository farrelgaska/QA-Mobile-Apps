export const STAFF_WAREHOUSE_ROLE = 'STAFF_WAREHOUSE' as const;
export const ADMIN_ROLE = 'ADMIN' as const;

export type StaffWarehouseRoleValue =
  | typeof STAFF_WAREHOUSE_ROLE
  | 'Staff Warehouse'
  | 'QA_STAFF'
  | 'qa_staff'
  | 'QA Staff'
  | 'Staff QA';

const normalizeRole = (role: string) =>
  role.trim().toUpperCase().replace(/[\s-]+/g, '_');

export const isStaffWarehouseRole = (role: string) => {
  const normalized = normalizeRole(role);
  return normalized === STAFF_WAREHOUSE_ROLE ||
    normalized === 'QA_STAFF' ||
    normalized === 'STAFF_QA';
};

export const isAdminRole = (role: string) => normalizeRole(role) === ADMIN_ROLE;

export const roleDisplayLabel = (role: string) => {
  if (isStaffWarehouseRole(role)) return 'Staff Warehouse';
  if (isAdminRole(role)) return 'Admin';
  return role.trim();
};

export const canCreateQCReports = (role: string) => isStaffWarehouseRole(role);
export const canSubmitQCReports = (role: string) => isStaffWarehouseRole(role);
export const canReviewQCReports = (role: string) => isAdminRole(role);
