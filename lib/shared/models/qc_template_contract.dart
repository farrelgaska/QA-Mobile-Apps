import 'checklist_item_model.dart';
import 'enums.dart';
import 'pekerjaan_model.dart';
import 'qc_material_template_model.dart';
import 'template_choice_option.dart';

class QCTemplateContract {
  static QCMaterialTemplate material(Map<String, dynamic> json) {
    return QCMaterialTemplate(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      code: _string(json, 'form_code', alias: 'formCode'),
      description: _string(json, 'description'),
      isActive: _boolean(json, 'is_active', alias: 'isActive'),
      checklistItems: _items(json).map(_materialItem).toList(),
    );
  }

  static PekerjaanModel work(Map<String, dynamic> json) {
    return PekerjaanModel(
      id: _string(json, 'id'),
      formCode: _string(json, 'form_code', alias: 'formCode'),
      name: _string(json, 'name'),
      segment: _segment(json),
      description: _string(json, 'description'),
      isActive: _boolean(json, 'is_active', alias: 'isActive'),
      checklistItems: _items(json).map(_workItem).toList(),
      status: _boolean(json, 'is_active', alias: 'isActive')
          ? 'Aktif'
          : 'Nonaktif',
    );
  }

  static QCChecklistItem _materialItem(Map<String, dynamic> item) {
    final bounds = _bounds(item);
    return QCChecklistItem(
      id: _string(item, 'id'),
      label: _string(item, 'parameter_name', alias: 'parameterName'),
      category: _string(item, 'category', fallback: 'Parameter'),
      inputType: _qcInputType(item),
      unit: _nullableString(item['unit']),
      standardText: _string(item, 'standard_text', alias: 'standardText'),
      validationRule: bounds,
      minValue: _number(item, 'min_value', alias: 'minValue'),
      maxValue: _number(item, 'max_value', alias: 'maxValue'),
      required: _boolean(item, 'is_required', alias: 'isRequired'),
      requiredPhoto: _boolean(
        item,
        'required_photo',
        alias: 'requiredPhoto',
      ),
      isActive: _boolean(item, 'is_active', alias: 'isActive'),
      isCritical: _boolean(item, 'is_critical', alias: 'isCritical'),
      choiceOptions: _choiceOptions(item),
    );
  }

  static ChecklistItemModel _workItem(Map<String, dynamic> item) =>
      ChecklistItemModel(
        id: _string(item, 'id'),
        title: _string(item, 'parameter_name', alias: 'parameterName'),
        inputType: _inputType(item),
        unit: _nullableString(item['unit']),
        standard: _string(item, 'standard_text', alias: 'standardText'),
        minValue: _number(item, 'min_value', alias: 'minValue'),
        maxValue: _number(item, 'max_value', alias: 'maxValue'),
        required: _boolean(item, 'is_required', alias: 'isRequired'),
        requiredPhoto: _boolean(
          item,
          'required_photo',
          alias: 'requiredPhoto',
        ),
        isActive: _boolean(item, 'is_active', alias: 'isActive'),
        isCritical: _boolean(item, 'is_critical', alias: 'isCritical'),
        choiceOptions: _choiceOptions(item),
      );

  static List<Map<String, dynamic>> _items(Map<String, dynamic> json) {
    final raw = json['checklist_items'] ?? json['checklistItems'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<TemplateChoiceOption> _choiceOptions(Map<String, dynamic> item) {
    final raw = item['choice_options'] ?? item['choiceOptions'];
    if (raw is! List) return const [];
    final options = raw
        .whereType<Map>()
        .map((e) => TemplateChoiceOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    options.sort((a, b) => a.position.compareTo(b.position));
    return options;
  }

  static InputType _inputType(Map<String, dynamic> json) {
    switch (_string(json, 'input_type', alias: 'inputType').toLowerCase()) {
      case 'number': return InputType.number;
      case 'text': return InputType.text;
      case 'choice': return InputType.choice;
      default: throw FormatException('Unsupported input_type');
    }
  }

  static QCInputType _qcInputType(Map<String, dynamic> json) {
    switch (_inputType(json)) {
      case InputType.number: return QCInputType.number;
      case InputType.text: return QCInputType.text;
      case InputType.choice: return QCInputType.choice;
    }
  }

  static QCValidationRule? _bounds(Map<String, dynamic> json) {
    final min = _number(json, 'min_value', alias: 'minValue');
    final max = _number(json, 'max_value', alias: 'maxValue');
    if (min == null && max == null) return null;
    return QCValidationRule(
      type: min != null && max != null
          ? QCValidationType.range
          : min != null ? QCValidationType.min : QCValidationType.max,
      minValue: min,
      maxValue: max,
    );
  }

  static WorkSegment _segment(Map<String, dynamic> json) {
    final value = '${json['segment'] ?? json['category'] ?? ''}'.toLowerCase();
    if (value.contains('assurance')) return WorkSegment.assurance;
    if (value.contains('construction')) return WorkSegment.construction;
    return WorkSegment.provisioning;
  }
}

String _string(Map<String, dynamic> json, String key, {String? alias, String fallback = ''}) =>
    (json[key] ?? (alias == null ? null : json[alias]))?.toString() ?? fallback;
bool _boolean(Map<String, dynamic> json, String key, {String? alias}) =>
    (json[key] ?? (alias == null ? null : json[alias])) == true;
double? _number(Map<String, dynamic> json, String key, {String? alias}) {
  final value = json[key] ?? (alias == null ? null : json[alias]);
  return value is num ? value.toDouble() : double.tryParse('$value');
}
String? _nullableString(dynamic value) => value == null || '$value'.isEmpty ? null : '$value';
