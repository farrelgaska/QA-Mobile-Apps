class TemplateChoiceOption {
  final String id;
  final String label;
  final String value;
  final String outcome;
  final int position;

  const TemplateChoiceOption({
    required this.id,
    required this.label,
    required this.value,
    required this.outcome,
    required this.position,
  });

  factory TemplateChoiceOption.fromJson(Map<String, dynamic> json) =>
      TemplateChoiceOption(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
        outcome: json['outcome']?.toString() ?? '',
        position: json['position'] is num
            ? (json['position'] as num).toInt()
            : int.tryParse('${json['position']}') ?? 0,
      );
}

TemplateChoiceOption? choiceOptionForValue(
  Iterable<TemplateChoiceOption> options,
  String value,
) {
  for (final option in options) {
    if (option.value == value) return option;
  }
  return null;
}
