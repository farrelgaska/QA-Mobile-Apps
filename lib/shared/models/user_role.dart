abstract final class UserRoles {
  static const String staffWarehouse = 'STAFF_WAREHOUSE';
  static const String admin = 'ADMIN';
  static const String staffWarehouseLabel = 'Staff Warehouse';
  static const String adminLabel = 'Admin';

  static String normalize(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');

  static bool isStaffWarehouse(String value) {
    final normalized = normalize(value);
    return normalized == staffWarehouse ||
        normalized == 'QA_STAFF' ||
        normalized == 'STAFF_QA';
  }

  static bool isAdmin(String value) => normalize(value) == admin;

  static String displayLabel(String value) {
    if (isStaffWarehouse(value)) return staffWarehouseLabel;
    if (isAdmin(value)) return adminLabel;
    return value.trim();
  }
}
