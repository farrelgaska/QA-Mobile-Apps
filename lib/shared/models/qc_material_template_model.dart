import 'enums.dart';

class QCMaterialTemplate {
  final String id;
  final String name;
  final String code;
  final String description;
  final List<QCChecklistItem> checklistItems;

  QCMaterialTemplate({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.checklistItems,
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
