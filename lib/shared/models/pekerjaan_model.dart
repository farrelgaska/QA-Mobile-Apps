import 'enums.dart';
import 'checklist_item_model.dart';

class PekerjaanModel {
  final String id;
  final String name;
  final WorkSegment segment;
  final String description;
  final List<ChecklistItemModel> checklistItems;
  final String status;

  PekerjaanModel({
    required this.id,
    required this.name,
    required this.segment,
    required this.description,
    required this.checklistItems,
    required this.status,
  });
}
