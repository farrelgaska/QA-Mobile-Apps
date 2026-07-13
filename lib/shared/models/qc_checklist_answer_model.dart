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
  })  : paramName = paramName ?? '',
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
      itemId: json['id'] ?? json['itemId'] ?? '',
      paramName: json['parameter_name'] ?? json['paramName'] ?? '',
      inputType: json['input_type'] ?? json['inputType'] ?? 'text',
      standardText: json['standard_text'] ?? json['standardText'] ?? '',
      unit: json['unit'],
      value: json['actual_value'] ?? json['value'] ?? '',
      issueNote: json['staff_note'] ?? json['issueNote'] ?? '',
      photoPaths: List<String>.from(json['item_photos'] ?? json['photoPaths'] ?? []),
      status: parsedStatus,
      adminNote: json['admin_note'] ?? json['adminNote'] ?? '',
      warningMessage: json['warningMessage'],
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
}
