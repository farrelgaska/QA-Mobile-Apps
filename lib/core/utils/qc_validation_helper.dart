import '../../shared/models/enums.dart';
import '../../shared/models/qc_material_template_model.dart';
import '../../shared/models/qc_checklist_answer_model.dart';
import '../../shared/models/template_choice_option.dart';

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

    // 2. Parse numeric input and evaluate only against canonical structured
    // bounds. Standard text is intentionally never guessed here.
    if (item.inputType == QCInputType.number) {
      final normalizedVal = valStr.replaceAll(',', '.');
      final valNum = double.tryParse(normalizedVal);
      if (valNum == null || !valNum.isFinite) {
        return QCValidationResult(
          status: QCResultStatus.notFilled,
          warningMessage: 'Input harus berupa angka',
          isValid: false,
        );
      }

      final minimum = item.minValue ?? item.validationRule?.minValue;
      final maximum = item.maxValue ?? item.validationRule?.maxValue;
      if (minimum == null && maximum == null) {
        return QCValidationResult(
          status: QCResultStatus.notFilled,
          warningMessage: null,
          isValid: true,
        );
      }
      final outsideStandard = (minimum != null && valNum < minimum) ||
          (maximum != null && valNum > maximum);
      return QCValidationResult(
        status: outsideStandard ? QCResultStatus.fail : QCResultStatus.pass,
        warningMessage: null,
        isValid: true,
      );
    }

    // 3. Structured choice outcomes are authoritative. Legacy choices use a
    // conservative label mapping and only fall back to their historical order.
    if (item.inputType == QCInputType.choice) {
      final options = resolvedChoiceOptions(
        item.choiceOptions,
        item.choices ?? const <String>[],
      );
      final outcome = choiceOptionForValue(options, valStr)?.outcome;
      return QCValidationResult(
        status: statusForOutcome(outcome),
        warningMessage: null,
        isValid: outcome == 'PASS' || outcome   == 'FAIL',
      );
    }

    // 4. Boolean outcomes prefer structured template data, then known safe
    // positive/negative labels for backward compatibility.
    if (item.inputType == QCInputType.booleanCheck) {
      final option = choiceOptionForValue(item.choiceOptions, valStr);
      final status = option == null
          ? statusForLegacyBoolean(valStr)
          : statusForOutcome(option.outcome);
      return QCValidationResult(
        status: status,
        warningMessage: null,
        isValid: status != QCResultStatus.notFilled,
      );
    }

    // Text/photo requires an explicit Staff decision in the provider/UI.
    return QCValidationResult(
      status: QCResultStatus.notFilled,
      warningMessage: null,
      isValid: true,
    );
  }

  static QCResultStatus statusForOutcome(String? outcome) {
    return switch (outcome?.toUpperCase()) {
      'PASS' => QCResultStatus.pass,
      'FAIL' => QCResultStatus.fail,
      _ => QCResultStatus.notFilled,
    };
  }

  static QCResultStatus statusForLegacyBoolean(String value) {
    return switch (value.trim().toLowerCase()) {
      'ya' || 'sesuai' || 'ok' => QCResultStatus.pass,
      'tidak' || 'tidak sesuai' => QCResultStatus.fail,
      _ => QCResultStatus.notFilled,
    };
  }

  static List<TemplateChoiceOption> resolvedChoiceOptions(
    List<TemplateChoiceOption> structured,
    List<String> legacy,
  ) {
    if (structured.isNotEmpty) return structured;
    return legacy.asMap().entries.map((entry) {
      final inferred = statusForLegacyBoolean(entry.value);
      final outcome = switch (inferred) {
        QCResultStatus.pass => 'PASS',
        QCResultStatus.fail => 'FAIL',
        _ => entry.key == 0 ? 'PASS' : 'FAIL',
      };
      return TemplateChoiceOption(
        id: 'legacy-choice-${entry.key}',
        label: entry.value,
        value: entry.value,
        outcome: outcome,
        position: entry.key,
      );
    }).toList(growable: false);
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
      if (item.required &&
          (answer.value == null || answer.value.toString().trim().isEmpty)) {
        errors.add('Aspek "${item.label}" wajib diisi.');
        hasIncomplete = true;
      }

      // 2. Required photo validation
      if (item.requiredPhoto && answer.photoPaths.isEmpty) {
        errors.add('Dokumentasi foto wajib diunggah untuk "${item.label}".');
        hasIncomplete = true;
      }

      // 3. Checked Fail / Need Follow Up status validation
      if (answer.status == QCResultStatus.fail ||
          answer.status == QCResultStatus.needFollowUp) {
        hasFail = true;
        if ((answer.issueNote ?? '').trim().isEmpty) {
          errors.add(
            'Keterangan masalah wajib diisi untuk "${item.label}".',
          );
          hasIncomplete = true;
        }
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
