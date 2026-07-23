import 'site_model.dart';
import 'user_role.dart';

class UserModel {
  final String id;
  final String name;
  final String role;
  final String nik;
  final SiteModel site;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.nik,
    required this.site,
  });

  String get roleLabel => UserRoles.displayLabel(role);
  bool get isStaffWarehouse => UserRoles.isStaffWarehouse(role);
  bool get isAdmin => UserRoles.isAdmin(role);
  bool get canCreateQCReports => isStaffWarehouse;
  bool get canSubmitQCReports => isStaffWarehouse;
  bool get canReviewQCReports => isAdmin;
}
