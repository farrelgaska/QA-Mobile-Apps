import 'enums.dart';
import 'qc_checklist_answer_model.dart';
import 'work_location_model.dart';

class QCReportChecklistResult {
  final String itemId;
  final String paramName;
  final String standard;
  final String inputType;
  final String? unit;
  final String resultValue;
  final ChecklistStatus status;
  final String issueNote;
  final List<String> photos;

  QCReportChecklistResult({
    required this.itemId,
    required this.paramName,
    required this.standard,
    required this.inputType,
    this.unit,
    required this.resultValue,
    required this.status,
    required this.issueNote,
    required this.photos,
  });

  QCReportChecklistResult copyWith({
    String? itemId,
    String? paramName,
    String? standard,
    String? inputType,
    String? unit,
    String? resultValue,
    ChecklistStatus? status,
    String? issueNote,
    List<String>? photos,
  }) {
    return QCReportChecklistResult(
      itemId: itemId ?? this.itemId,
      paramName: paramName ?? this.paramName,
      standard: standard ?? this.standard,
      inputType: inputType ?? this.inputType,
      unit: unit ?? this.unit,
      resultValue: resultValue ?? this.resultValue,
      status: status ?? this.status,
      issueNote: issueNote ?? this.issueNote,
      photos: photos ?? this.photos,
    );
  }
}

class QCReportModel {
  final String id;
  final String title;
  final QCType type;
  final QCReportStatus status;
  final String checkedByName;
  final String checkedByNik;
  final String createdByNik;
  final DateTime date;
  final String siteId;
  final String siteName;
  final String area;
  final String detailLocation;
  
  // Backward compatibility list
  final List<QCReportChecklistResult>? checklistResults;
  
  // New dynamic list
  final List<QCChecklistAnswer>? checklistAnswers;
  
  final List<String> photos;
  final String staffNote;
  final String? adminNote;
  
  // Dynamic QC Material fields
  final String? formCode;
  final WorkLocation? workLocation;
  final Map<String, String>? generalInfo;
  final String? finalConclusion;

  QCReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.checkedByName,
    required this.checkedByNik,
    required this.date,
    required this.siteId,
    required this.siteName,
    required this.area,
    required this.detailLocation,
    this.checklistResults,
    this.checklistAnswers,
    required this.photos,
    required this.staffNote,
    this.adminNote,
    this.formCode,
    this.workLocation,
    this.generalInfo,
    this.finalConclusion,
    String? createdByNik,
  }) : createdByNik = createdByNik ?? checkedByNik;

  QCReportModel copyWith({
    String? id,
    String? title,
    QCType? type,
    QCReportStatus? status,
    String? checkedByName,
    String? checkedByNik,
    String? createdByNik,
    DateTime? date,
    String? siteId,
    String? siteName,
    String? area,
    String? detailLocation,
    List<QCReportChecklistResult>? checklistResults,
    List<QCChecklistAnswer>? checklistAnswers,
    List<String>? photos,
    String? staffNote,
    String? adminNote,
    String? formCode,
    WorkLocation? workLocation,
    Map<String, String>? generalInfo,
    String? finalConclusion,
  }) {
    return QCReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      checkedByName: checkedByName ?? this.checkedByName,
      checkedByNik: checkedByNik ?? this.checkedByNik,
      createdByNik: createdByNik ?? this.createdByNik,
      date: date ?? this.date,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      area: area ?? this.area,
      detailLocation: detailLocation ?? this.detailLocation,
      checklistResults: checklistResults ?? this.checklistResults,
      checklistAnswers: checklistAnswers ?? this.checklistAnswers,
      photos: photos ?? this.photos,
      staffNote: staffNote ?? this.staffNote,
      adminNote: adminNote ?? this.adminNote,
      formCode: formCode ?? this.formCode,
      workLocation: workLocation ?? this.workLocation,
      generalInfo: generalInfo ?? this.generalInfo,
      finalConclusion: finalConclusion ?? this.finalConclusion,
    );
  }
}
