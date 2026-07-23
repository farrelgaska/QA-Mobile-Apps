import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/dummy/dummy_sites.dart';
import 'package:mobile/shared/models/user_model.dart';
import 'package:mobile/shared/models/user_role.dart';

UserModel _userWithRole(String role) => UserModel(
  id: 'role-test',
  name: 'Role Test',
  role: role,
  nik: 'ROLE-1',
  site: dummySites.first,
);

void main() {
  test('legacy QA Staff role values remain Staff Warehouse roles', () {
    for (final legacyRole in ['QA_STAFF', 'qa_staff', 'QA Staff', 'Staff QA']) {
      final user = _userWithRole(legacyRole);

      expect(user.isStaffWarehouse, isTrue, reason: legacyRole);
      expect(user.roleLabel, UserRoles.staffWarehouseLabel);
      expect(user.canCreateQCReports, isTrue);
      expect(user.canSubmitQCReports, isTrue);
      expect(user.canReviewQCReports, isFalse);
    }
  });

  test('canonical Staff Warehouse can create and submit but cannot review', () {
    final user = _userWithRole(UserRoles.staffWarehouse);

    expect(user.roleLabel, 'Staff Warehouse');
    expect(user.canCreateQCReports, isTrue);
    expect(user.canSubmitQCReports, isTrue);
    expect(user.canReviewQCReports, isFalse);
  });

  test('Admin remains the only supported report reviewer', () {
    for (final adminRole in ['ADMIN', 'Admin', 'admin']) {
      final user = _userWithRole(adminRole);

      expect(user.isAdmin, isTrue);
      expect(user.canReviewQCReports, isTrue);
      expect(user.canCreateQCReports, isFalse);
      expect(user.canSubmitQCReports, isFalse);
    }

    expect(_userWithRole('unknown').canReviewQCReports, isFalse);
  });
}
