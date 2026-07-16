import 'enums.dart';
import 'template_choice_option.dart';

class ChecklistItemModel {
  final String id;
  final String title;
  final InputType inputType;
  final String? unit;
  final String standard;
  final bool requiredPhoto;
  final bool required;
  final bool isActive;
  final bool isCritical;
  final List<String>? choices;
  final List<TemplateChoiceOption> choiceOptions;
  final double? minValue;
  final double? maxValue;

  ChecklistItemModel({
    required this.id,
    required this.title,
    required this.inputType,
    this.unit,
    required this.standard,
    required this.requiredPhoto,
    this.required = true,
    this.isActive = true,
    this.isCritical = false,
    this.choices,
    this.choiceOptions = const [],
    this.minValue,
    this.maxValue,
  });
}
