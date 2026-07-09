import '../dummy/dummy_state.dart';
import '../../shared/models/user_model.dart';

class DummyAuth {
  static UserModel get current => DummyState().currentUser;
}
