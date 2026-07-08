import '../../shared/models/user_model.dart';
import 'dummy_sites.dart';

final List<UserModel> dummyUsers = [
  UserModel(
    id: 'user-1',
    name: 'Yanuar Luthfi',
    role: 'QA Staff',
    nik: 'NIK-908271',
    site: dummySites[0],
  ),
  UserModel(
    id: 'user-2',
    name: 'Budi Santoso',
    role: 'QA Staff',
    nik: 'NIK-908272',
    site: dummySites[1],
  ),
  UserModel(
    id: 'user-3',
    name: 'Siti Rahma',
    role: 'QA Staff',
    nik: 'NIK-908273',
    site: dummySites[2],
  ),
  UserModel(
    id: 'user-4',
    name: 'Agus Setiawan',
    role: 'QA Staff',
    nik: 'NIK-908274',
    site: dummySites[3],
  ),
];
