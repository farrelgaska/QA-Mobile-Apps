import '../../shared/models/enums.dart';

class QCValidators {
  static bool isValidNumber(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return false;
    return double.tryParse(normalized) != null;
  }
}
