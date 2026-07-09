import '../../../shared/models/enums.dart';
import '../../../shared/models/qc_material_template_model.dart';

class QCEvaluationService {
  // Evaluates a QC Material template item and returns QCResultStatus (Simulated Admin Side logic)
  static QCResultStatus evaluateMaterialItem({
    required QCChecklistItem item,
    required String value,
  }) {
    final valStr = value.trim();
    if (valStr.isEmpty) {
      return QCResultStatus.notFilled;
    }

    final lowerVal = valStr.toLowerCase();

    // 1. Choice/Boolean checks
    if (item.inputType == QCInputType.choice || item.inputType == QCInputType.booleanCheck) {
      final passKeywords = [
        'sesuai', 'ya', 'ok', 'ada', 'lengkap', 'rapi', 'kencang', 'bersih', 
        'tegak lurus', 'sesuai standar', 'true', 'diterima'
      ];
      final isPass = passKeywords.contains(lowerVal);
      return isPass ? QCResultStatus.pass : QCResultStatus.fail;
    }

    // 2. Numeric checks
    final rule = item.validationRule;
    if (item.inputType == QCInputType.number) {
      final normalizedVal = valStr.replaceAll(',', '.');
      final valNum = double.tryParse(normalizedVal);
      if (valNum == null) {
        return QCResultStatus.fail;
      }

      if (rule != null) {
        switch (rule.type) {
          case QCValidationType.range:
            if (rule.minValue != null && valNum < rule.minValue!) {
              return QCResultStatus.fail;
            }
            if (rule.maxValue != null && valNum > rule.maxValue!) {
              return QCResultStatus.fail;
            }
            break;

          case QCValidationType.min:
            if (rule.minValue != null && valNum < rule.minValue!) {
              return QCResultStatus.fail;
            }
            break;

          case QCValidationType.max:
            if (rule.maxValue != null && valNum > rule.maxValue!) {
              return QCResultStatus.fail;
            }
            break;

          case QCValidationType.exact:
            if (rule.exactValue != null && valNum != rule.exactValue!) {
              return QCResultStatus.fail;
            }
            break;

          default:
            break;
        }
      }
      return QCResultStatus.pass;
    }

    // 3. Exact text validation fallback
    if (rule != null && rule.type == QCValidationType.exact) {
      final exactStr = rule.exactValue?.toString() ?? '';
      if (valStr != exactStr.trim()) {
        return QCResultStatus.fail;
      }
    }

    return QCResultStatus.pass;
  }

  // Evaluates a QC Pekerjaan item and returns ChecklistStatus (Simulated Admin Side logic)
  static ChecklistStatus evaluatePekerjaanItem({
    required String title,
    required InputType inputType,
    required String value,
  }) {
    final valStr = value.trim();
    if (valStr.isEmpty) {
      return ChecklistStatus.belumDiisi;
    }

    if (inputType == InputType.number) {
      final parsed = double.tryParse(valStr.replaceAll(',', '.'));
      if (parsed == null) {
        return ChecklistStatus.belumDiisi;
      }
      final lowerTitle = title.toLowerCase();
      if (lowerTitle.contains('redaman')) {
        if (parsed >= -24 && parsed <= -15) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      if (lowerTitle.contains('kedalaman')) {
        if (parsed >= 1.2) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      if (lowerTitle.contains('pengeringan')) {
        if (parsed >= 24) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      if (lowerTitle.contains('ketinggian')) {
        if (parsed >= 5) {
          return ChecklistStatus.lulus;
        }
        return ChecklistStatus.tidakSesuai;
      }
      return ChecklistStatus.lulus;
    } else if (inputType == InputType.choice) {
      final lowerVal = valStr.toLowerCase();
      final passKeywords = [
        'sesuai', 'rapi', 'kencang', 'bersih', 'ada & jelas', 
        'tegak lurus', 'sesuai standar', 'lengkap', 'ya', 'ok'
      ];
      if (passKeywords.contains(lowerVal)) {
        return ChecklistStatus.lulus;
      }
      return ChecklistStatus.tidakSesuai;
    } else {
      return ChecklistStatus.lulus;
    }
  }
}
