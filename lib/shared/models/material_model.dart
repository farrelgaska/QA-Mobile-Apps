import 'checklist_item_model.dart';

class MaterialModel {
  final String id;
  final String name;
  final String type;
  final List<ChecklistItemModel> checklistItems;
  final String status; // e.g. "Aktif", "Nonaktif"

  MaterialModel({
    required this.id,
    required this.name,
    required this.type,
    required this.checklistItems,
    required this.status,
  });
}
