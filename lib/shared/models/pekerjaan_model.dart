import 'enums.dart';
import 'checklist_item_model.dart';

class PekerjaanModel {
  final String id;
  final String formCode;
  final String name;
  final WorkSegment segment;
  final String description;
  final List<ChecklistItemModel> checklistItems;
  final String status;
  final bool isActive;

  PekerjaanModel({
    required this.id,
    this.formCode = '',
    required this.name,
    required this.segment,
    required this.description,
    required this.checklistItems,
    required this.status,
    this.isActive = true,
  });
}
