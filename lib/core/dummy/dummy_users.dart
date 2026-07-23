import '../../shared/models/user_model.dart';
import '../../shared/models/user_role.dart';
import 'dummy_sites.dart';

final List<UserModel> dummyUsers = [
  UserModel(
    id: 'user-1',
    name: 'Yanuar Luthfi',
    role: UserRoles.staffWarehouse,
    nik: 'NIK-908271',
    site: dummySites[0],
  ),
  UserModel(
    id: 'user-2',
    name: 'Budi Santoso',
    role: UserRoles.staffWarehouse,
    nik: 'NIK-908272',
    site: dummySites[1],
  ),
  UserModel(
    id: 'user-3',
    name: 'Siti Rahma',
    role: UserRoles.staffWarehouse,
    nik: 'NIK-908273',
    site: dummySites[2],
  ),
  UserModel(
    id: 'user-4',
    name: 'Agus Setiawan',
    role: UserRoles.staffWarehouse,
    nik: 'NIK-908274',
    site: dummySites[3],
  ),
  UserModel(
    id: 'user-admin',
    name: 'Budi (Admin)',
    role: UserRoles.admin,
    nik: 'admin',
    site: dummySites[0],
  ),
];
