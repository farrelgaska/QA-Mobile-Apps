import 'enums.dart';

class ChecklistItemModel {
  final String id;
  final String title;
  final InputType inputType;
  final String? unit;
  final String standard;
  final bool requiredPhoto;
  final bool isCritical;
  final List<String>? choices;

  ChecklistItemModel({
    required this.id,
    required this.title,
    required this.inputType,
    this.unit,
    required this.standard,
    required this.requiredPhoto,
    this.isCritical = false,
    this.choices,
  });
}
