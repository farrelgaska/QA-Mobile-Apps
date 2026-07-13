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

    // 2. If it's a choice or booleanCheck — staff selects the option, Admin evaluates standard compliance
    if (item.inputType == QCInputType.choice || item.inputType == QCInputType.booleanCheck) {
      // Staff-side: just mark as filled, Admin evaluates PASS/FAIL
      return QCValidationResult(
        status: QCResultStatus.notFilled, // neutral: "filled but not evaluated"
        warningMessage: null,
        isValid: true,
      );
    }

    // 3. Parse numeric value — staff only validates it's a valid number, not vs standard
    if (item.inputType == QCInputType.number) {
      // Replace commas with dots for decimals
      final normalizedVal = valStr.replaceAll(',', '.');
      final valNum = double.tryParse(normalizedVal);
      if (valNum == null) {
        return QCValidationResult(
          status: QCResultStatus.notFilled,
          warningMessage: 'Input harus berupa angka',
          isValid: false,
        );
      }

      if (valNum < 0) {
        return QCValidationResult(
          status: QCResultStatus.notFilled,
          warningMessage: 'Nilai tidak boleh negatif',
          isValid: false,
        );
      }

      // Valid number — Admin will evaluate against standard
      return QCValidationResult(
        status: QCResultStatus.notFilled, // neutral: filled, not yet evaluated
        warningMessage: null,
        isValid: true,
      );
    }

    // For text input: valid as long as not empty
    return QCValidationResult(
      status: QCResultStatus.notFilled, // neutral: filled, not yet evaluated
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
