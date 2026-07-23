import 'enums.dart';

class QCChecklistAnswer {
  final String itemId;
  dynamic value;
  QCResultStatus status;
  String? warningMessage;
  String? issueNote;
  List<String> photoPaths;

  // Standard fields
  String paramName;
  String standardText;
  String? unit;
  String inputType;
  String? adminNote;
  double? standardValue;
  double? upperTolerance;
  double? lowerTolerance;
  double? minimumValue;
  double? maximumValue;
  String evaluationStatus;

  QCChecklistAnswer({
    required this.itemId,
    required this.value,
    required this.status,
    this.warningMessage,
    this.issueNote,
    required this.photoPaths,
    String? paramName,
    String? standardText,
    this.unit,
    String? inputType,
    this.adminNote,
    this.standardValue,
    this.upperTolerance,
    this.lowerTolerance,
    this.minimumValue,
    this.maximumValue,
    this.evaluationStatus = 'NOT_EVALUATED',
  }) : paramName = paramName ?? '',
       standardText = standardText ?? '',
       inputType = inputType ?? 'text';

  QCChecklistAnswer copyWith({
    String? itemId,
    dynamic value,
    QCResultStatus? status,
    String? warningMessage,
    String? issueNote,
    List<String>? photoPaths,
    String? paramName,
    String? standardText,
    String? unit,
    String? inputType,
    String? adminNote,
    double? standardValue,
    double? upperTolerance,
    double? lowerTolerance,
    double? minimumValue,
    double? maximumValue,
    String? evaluationStatus,
  }) {
    return QCChecklistAnswer(
      itemId: itemId ?? this.itemId,
      value: value ?? this.value,
      status: status ?? this.status,
      warningMessage: warningMessage ?? this.warningMessage,
      issueNote: issueNote ?? this.issueNote,
      photoPaths: photoPaths ?? this.photoPaths,
      paramName: paramName ?? this.paramName,
      standardText: standardText ?? this.standardText,
      unit: unit ?? this.unit,
      inputType: inputType ?? this.inputType,
      adminNote: adminNote ?? this.adminNote,
      standardValue: standardValue ?? this.standardValue,
      upperTolerance: upperTolerance ?? this.upperTolerance,
      lowerTolerance: lowerTolerance ?? this.lowerTolerance,
      minimumValue: minimumValue ?? this.minimumValue,
      maximumValue: maximumValue ?? this.maximumValue,
      evaluationStatus: evaluationStatus ?? this.evaluationStatus,
    );
  }

  factory QCChecklistAnswer.fromJson(Map<String, dynamic> json) {
    QCResultStatus parsedStatus = QCResultStatus.notFilled;
    final statusStr = json['admin_evaluation'] ?? json['status'];
    if (statusStr == 'PASS' || statusStr == 'pass') {
      parsedStatus = QCResultStatus.pass;
    } else if (statusStr == 'FAIL' || statusStr == 'fail') {
      parsedStatus = QCResultStatus.fail;
    } else if (statusStr == 'needFollowUp' || statusStr == 'NEEDS_FOLLOW_UP') {
      parsedStatus = QCResultStatus.needFollowUp;
    }

    return QCChecklistAnswer(
      itemId: json['id'] ?? json['itemId'] ?? json['checklist_item_id'] ?? '',
      paramName: json['parameter_name'] ?? json['paramName'] ?? '',
      inputType: json['input_type'] ?? json['inputType'] ?? 'text',
      standardText: json['standard_text'] ?? json['standardText'] ?? '',
      unit: json['unit'],
      value: json['actual_value'] ?? json['value'] ?? '',
      issueNote: json['staff_note'] ?? json['issueNote'] ?? json['note'] ?? '',
      photoPaths: List<String>.from(
        json['item_photos'] ?? json['photoPaths'] ?? json['photo_paths'] ?? [],
      ),
      status: parsedStatus,
      adminNote: json['admin_note'] ?? json['adminNote'] ?? '',
      warningMessage: json['warningMessage'],
      standardValue: _asDouble(json['standard_value']),
      upperTolerance: _asDouble(json['upper_tolerance']),
      lowerTolerance: _asDouble(json['lower_tolerance']),
      minimumValue: _asDouble(json['minimum_value']),
      maximumValue: _asDouble(json['maximum_value']),
      evaluationStatus:
          json['evaluation_status']?.toString() ?? 'NOT_EVALUATED',
    );
  }

  Map<String, dynamic> toJson() {
    // Staff never evaluates PASS/FAIL — always submit as NEEDS_REVIEW for Admin to evaluate.
    return {
      'id': itemId,
      'parameter_name': paramName,
      'input_type': inputType,
      'standard_text': standardText,
      'unit': unit,
      'actual_value': value?.toString() ?? '',
      'staff_note': issueNote ?? '',
      'item_photos': photoPaths,
      'admin_evaluation': 'NEEDS_REVIEW',
      'admin_note': adminNote ?? '',
    };
  }

  Map<String, dynamic> toSampleJson() {
    return {
      'checklist_item_id': itemId,
      'input_type': inputType,
      'actual_value': value,
      'note': issueNote ?? '',
      'photo_paths': photoPaths,
      'standard_text': standardText,
      'standard_value': standardValue,
      'unit': unit ?? '',
      'upper_tolerance': upperTolerance,
      'lower_tolerance': lowerTolerance,
      'minimum_value': minimumValue,
      'maximum_value': maximumValue,
      'evaluation_status': evaluationStatus,
    };
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
