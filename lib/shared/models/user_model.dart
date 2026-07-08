import 'site_model.dart';

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
}
