import 'enums.dart';

class QCChecklistAnswer {
  final String itemId;
  dynamic value;
  QCResultStatus status;
  String? warningMessage;
  String? issueNote;
  List<String> photoPaths;

  // Helper fields for rendering report detail page easily
  String? paramName;
  String? standardText;
  String? unit;

  QCChecklistAnswer({
    required this.itemId,
    required this.value,
    required this.status,
    this.warningMessage,
    this.issueNote,
    required this.photoPaths,
    this.paramName,
    this.standardText,
    this.unit,
  });

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
    );
  }
}
