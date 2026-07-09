import '../../shared/models/enums.dart';
import '../../shared/models/qc_material_template_model.dart';
import '../../shared/models/qc_checklist_answer_model.dart';

class QCValidationResult {
  final QCResultStatus status;
  final String? warningMessage;
  final bool isValid;

  QCValidationResult({
    required this.status,
    this.warningMessage,
    required this.isValid,
  });
}

class QCSubmitValidationResult {
  final bool canSubmit;
  final List<String> errors;
  final String finalConclusion;

  QCSubmitValidationResult({
    required this.canSubmit,
    required this.errors,
    required this.finalConclusion,
  });
}

class QCValidationHelper {
  static QCValidationResult validateChecklistAnswer({
    required QCChecklistItem item,
    required dynamic value,
  }) {
    // 1. Check if empty
    final valStr = value?.toString() ?? '';
    if (valStr.trim().isEmpty) {
      if (item.required) {
        return QCValidationResult(
          status: QCResultStatus.notFilled,
          warningMessage: 'Wajib diisi',
          isValid: false,
        );
      } else {
        return QCValidationResult(
          status: QCResultStatus.notFilled,
          warningMessage: null,
          isValid: true,
        );
      }
    }

    final lowerVal = valStr.trim().toLowerCase();

    // 2. If it's a choice or booleanCheck, map status based on positive keywords
    if (item.inputType == QCInputType.choice || item.inputType == QCInputType.booleanCheck) {
      final passKeywords = [
        'sesuai', 'ya', 'ok', 'ada', 'lengkap', 'rapi', 'kencang', 'bersih', 
        'tegak lurus', 'sesuai standar', 'true', 'diterima'
      ];
      final isPass = passKeywords.contains(lowerVal);
      return QCValidationResult(
        status: isPass ? QCResultStatus.pass : QCResultStatus.fail,
        warningMessage: null, // No warning message for out of standard
        isValid: true, // Always valid
      );
    }

    // 3. Parse numeric value if validation expects numbers
    if (item.inputType == QCInputType.number) {
      // Replace commas with dots for decimals
      final normalizedVal = valStr.replaceAll(',', '.');
      final valNum = double.tryParse(normalizedVal);
      if (valNum == null) {
        return QCValidationResult(
          status: QCResultStatus.fail,
          warningMessage: 'Input harus berupa angka',
          isValid: false,
        );
      }

      if (valNum < 0) {
        return QCValidationResult(
          status: QCResultStatus.fail,
          warningMessage: 'Nilai tidak boleh negatif',
          isValid: false,
        );
      }

      return QCValidationResult(
        status: QCResultStatus.pass,
        warningMessage: null,
        isValid: true,
      );
    }

    return QCValidationResult(
      status: QCResultStatus.pass,
      warningMessage: null,
      isValid: true,
    );
  }

  static QCSubmitValidationResult validateBeforeSubmit({
    required List<QCChecklistItem> items,
    required List<QCChecklistAnswer> answers,
  }) {
    final List<String> errors = [];
    bool hasFail = false;
    bool hasIncomplete = false;

    for (var item in items) {
      final answer = answers.firstWhere(
        (ans) => ans.itemId == item.id,
        orElse: () => QCChecklistAnswer(
          itemId: item.id,
          value: '',
          status: QCResultStatus.notFilled,
          photoPaths: [],
        ),
      );

      // 1. Required field validation
      if (item.required && (answer.value == null || answer.value.toString().trim().isEmpty)) {
        errors.add('Aspek "${item.label}" wajib diisi.');
        hasIncomplete = true;
      }

      // 2. Required Photo validation (all items must have at least 1 photo)
      if (answer.photoPaths.isEmpty) {
        errors.add('Dokumentasi foto wajib diunggah untuk "${item.label}".');
        hasIncomplete = true;
      }

      // 3. Checked Fail / Need Follow Up status validation
      if (answer.status == QCResultStatus.fail || answer.status == QCResultStatus.needFollowUp) {
        hasFail = true;
        // issueNote is no longer required on mobile
      }

      if (answer.status == QCResultStatus.notFilled && item.required) {
        hasIncomplete = true;
      }
    }

    // Determine conclusion
    String finalConclusion;
    if (hasIncomplete) {
      finalConclusion = 'Belum Lengkap';
    } else if (hasFail) {
      finalConclusion = 'Pending';
    } else {
      finalConclusion = 'Diterima';
    }

    // Submit rules check
    final bool canSubmit = errors.isEmpty && !hasIncomplete;

    return QCSubmitValidationResult(
      canSubmit: canSubmit,
      errors: errors,
      finalConclusion: finalConclusion,
    );
  }
}
