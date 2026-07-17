import 'enums.dart';
import 'template_choice_option.dart';

class QCMaterialTemplate {
  final String id;
  final String name;
  final String code;
  final String category;
  final String description;
  final List<QCChecklistItem> checklistItems;
  final bool isActive;

  QCMaterialTemplate({
    required this.id,
    required this.name,
    required this.code,
    this.category = 'QC Material',
    required this.description,
    required this.checklistItems,
    this.isActive = true,
  });
}

class QCChecklistItem {
  final String id;
  final String label;
  final String category;
  final QCInputType inputType;
  final String? unit;
  final String standardText;
  final QCValidationRule? validationRule;
  final bool required;
  final bool requiredPhoto;
  final List<String>? choices;
  final List<TemplateChoiceOption> choiceOptions;
  final double? minValue;
  final double? maxValue;
  final bool isActive;
  final bool isCritical;

  QCChecklistItem({
    required this.id,
    required this.label,
    required this.category,
    required this.inputType,
    this.unit,
    required this.standardText,
    this.validationRule,
    this.required = true,
    this.requiredPhoto = false,
    this.choices,
    this.choiceOptions = const [],
    this.minValue,
    this.maxValue,
    this.isActive = true,
    this.isCritical = false,
  });
}

class QCValidationRule {
  final QCValidationType type;
  final double? minValue;
  final double? maxValue;
  final double? exactValue;
  final String? warningBelow;
  final String? warningAbove;
  final String? warningInvalid;

  QCValidationRule({
    required this.type,
    this.minValue,
    this.maxValue,
    this.exactValue,
    this.warningBelow,
    this.warningAbove,
    this.warningInvalid,
  });
}
