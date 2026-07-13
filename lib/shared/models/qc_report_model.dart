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
  final String? adminNote;

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
    this.adminNote,
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
    String? adminNote,
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
      adminNote: adminNote ?? this.adminNote,
    );
  }
}

class StaffIdentity {
  final String name;
  final String nik;

  StaffIdentity({required this.name, required this.nik});
  
  Map<String, dynamic> toJson() => {'name': name, 'nik': nik};
  factory StaffIdentity.fromJson(Map<String, dynamic> json) => StaffIdentity(
    name: json['name'] ?? '',
    nik: json['nik'] ?? '',
  );
}

class ReportLocation {
  final String siteId;
  final String siteName;
  final String area;
  final String detailLocation;

  ReportLocation({
    required this.siteId,
    required this.siteName,
    required this.area,
    required this.detailLocation,
  });

  Map<String, dynamic> toJson() => {
    'site_id': siteId,
    'site_name': siteName,
    'area': area,
    'detail_location': detailLocation,
  };
  
  factory ReportLocation.fromJson(Map<String, dynamic> json) => ReportLocation(
    siteId: json['site_id'] ?? '',
    siteName: json['site_name'] ?? '',
    area: json['area'] ?? '',
    detailLocation: json['detail_location'] ?? '',
  );
}

class AdminReview {
  final String? adminNote;
  final String? reviewedAt;
  final String? conclusion;

  AdminReview({this.adminNote, this.reviewedAt, this.conclusion});

  Map<String, dynamic> toJson() => {
    'admin_note': adminNote,
    'reviewed_at': reviewedAt,
    'conclusion': conclusion,
  };
  
  factory AdminReview.fromJson(Map<String, dynamic> json) => AdminReview(
    adminNote: json['admin_note'],
    reviewedAt: json['reviewed_at'],
    conclusion: json['conclusion'],
  );
}

class QCReportModel {
  final String id;
  final String title;
  final QCType type;
  final QCReportStatus status;
  final StaffIdentity staff;
  final ReportLocation location;
  final Map<String, String> generalInfo;
  final List<QCChecklistAnswer> checklistItems;
  final String staffNote;
  final DateTime submittedAt;
  final AdminReview adminReview;
  final List<String> generalPhotos;
  final int revisionNumber;
  final List<QCReportModel> revisionHistory;
  
  // Template & form references
  final String formCode;
  final String templateId;
  final String? finalConclusion;

  QCReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    StaffIdentity? staff,
    ReportLocation? location,
    Map<String, String>? generalInfo,
    List<QCChecklistAnswer>? checklistItems,
    required this.staffNote,
    DateTime? submittedAt,
    AdminReview? adminReview,
    List<String>? generalPhotos,
    this.revisionNumber = 1,
    this.revisionHistory = const [],
    
    // Legacy / optional parameters for backwards compatibility
    String? checkedByName,
    String? checkedByNik,
    String? createdByNik,
    DateTime? date,
    String? siteId,
    String? siteName,
    String? area,
    String? detailLocation,
    List<QCChecklistAnswer>? checklistAnswers,
    List<QCReportChecklistResult>? checklistResults,
    List<String>? photos,
    String? adminNote,
    this.formCode = '',
    this.templateId = '',
    this.finalConclusion,
  })  : staff = staff ?? StaffIdentity(
          name: checkedByName ?? 'Yanuar Luthfi',
          nik: checkedByNik ?? createdByNik ?? 'NIK-908271',
        ),
        location = location ?? ReportLocation(
          siteId: siteId ?? 'site-1',
          siteName: siteName ?? 'Gudang Material Utama',
          area: area ?? 'Sektor Utama',
          detailLocation: detailLocation ?? '',
        ),
        generalInfo = generalInfo ?? {},
        checklistItems = checklistItems ?? checklistAnswers ?? 
            (checklistResults?.map((res) => QCChecklistAnswer(
              itemId: res.itemId,
              value: res.resultValue,
              status: _mapChecklistStatusToQCResultStatus(res.status),
              photoPaths: res.photos,
              paramName: res.paramName,
              standardText: res.standard,
              unit: res.unit,
              inputType: res.inputType,
              adminNote: adminNote,
            )).toList() ?? []),
        submittedAt = submittedAt ?? date ?? DateTime.now(),
        adminReview = adminReview ?? AdminReview(
          adminNote: adminNote,
          conclusion: finalConclusion,
        ),
        generalPhotos = generalPhotos ?? photos ?? [];

  // Legacy getters for backward compatibility
  String get checkedByName => staff.name;
  String get checkedByNik => staff.nik;
  String get createdByNik => staff.nik;
  DateTime get date => submittedAt;
  String get siteId => location.siteId;
  String get siteName => location.siteName;
  String get area => location.area;
  String get detailLocation => location.detailLocation;
  List<QCChecklistAnswer> get checklistAnswers => checklistItems;
  List<String> get photos => generalPhotos;
  String? get adminNote => adminReview.adminNote;
  
  WorkLocation get workLocation => WorkLocation(
    siteName: location.siteName,
    area: location.area,
    segment: location.detailLocation,
    isCustom: location.siteId == 'custom-site',
  );

  List<QCReportChecklistResult> get checklistResults => checklistItems.map((item) => QCReportChecklistResult(
    itemId: item.itemId,
    paramName: item.paramName,
    standard: item.standardText,
    inputType: item.inputType,
    unit: item.unit,
    resultValue: item.value?.toString() ?? '',
    status: _mapQCResultStatusToChecklistStatus(item.status),
    issueNote: item.issueNote ?? '',
    photos: item.photoPaths,
    adminNote: item.adminNote,
  )).toList();

  static ChecklistStatus _mapQCResultStatusToChecklistStatus(QCResultStatus status) {
    switch (status) {
      case QCResultStatus.pass:
        return ChecklistStatus.lulus;
      case QCResultStatus.fail:
        return ChecklistStatus.tidakSesuai;
      case QCResultStatus.needFollowUp:
        return ChecklistStatus.perluTindakLanjut;
      default:
        return ChecklistStatus.belumDiisi;
    }
  }

  static QCResultStatus _mapChecklistStatusToQCResultStatus(ChecklistStatus status) {
    switch (status) {
      case ChecklistStatus.lulus:
        return QCResultStatus.pass;
      case ChecklistStatus.tidakSesuai:
        return QCResultStatus.fail;
      case ChecklistStatus.perluTindakLanjut:
        return QCResultStatus.needFollowUp;
      default:
        return QCResultStatus.notFilled;
    }
  }

  QCReportModel copyWith({
    String? id,
    String? title,
    QCType? type,
    QCReportStatus? status,
    StaffIdentity? staff,
    ReportLocation? location,
    Map<String, String>? generalInfo,
    List<QCChecklistAnswer>? checklistItems,
    String? staffNote,
    DateTime? submittedAt,
    AdminReview? adminReview,
    List<String>? generalPhotos,
    int? revisionNumber,
    List<QCReportModel>? revisionHistory,
    String? formCode,
    String? templateId,
    String? finalConclusion,
  }) {
    return QCReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      staff: staff ?? this.staff,
      location: location ?? this.location,
      generalInfo: generalInfo ?? this.generalInfo,
      checklistItems: checklistItems ?? this.checklistItems,
      staffNote: staffNote ?? this.staffNote,
      submittedAt: submittedAt ?? this.submittedAt,
      adminReview: adminReview ?? this.adminReview,
      generalPhotos: generalPhotos ?? this.generalPhotos,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      revisionHistory: revisionHistory ?? this.revisionHistory,
      formCode: formCode ?? this.formCode,
      templateId: templateId ?? this.templateId,
      finalConclusion: finalConclusion ?? this.finalConclusion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type == QCType.material ? 'MATERIAL' : 'WORK',
      'template_id': templateId,
      'form_code': formCode,
      'title': title,
      'status': status.toString().split('.').last,
      'staff': staff.toJson(),
      'location': location.toJson(),
      'general_info': generalInfo,
      'checklist_items': checklistItems.map((i) => i.toJson()).toList(),
      'staff_note': staffNote,
      'submitted_at': submittedAt.toIso8601String(),
      'admin_review': adminReview.toJson(),
      'general_photos': generalPhotos,
      'revision_number': revisionNumber,
      'revision_history': revisionHistory.map((h) => h.toJson()).toList(),
    };
  }

  factory QCReportModel.fromJson(Map<String, dynamic> json) {
    QCReportStatus parsedStatus = QCReportStatus.DRAFT;
    final statusStr = json['status']?.toString().toUpperCase();
    if (statusStr == 'SUBMITTED') {
      parsedStatus = QCReportStatus.SUBMITTED;
    } else if (statusStr == 'NEEDS_FOLLOW_UP' || statusStr == 'NEED_FOLLOW_UP') {
      parsedStatus = QCReportStatus.NEEDS_FOLLOW_UP;
    } else if (statusStr == 'APPROVED') {
      parsedStatus = QCReportStatus.APPROVED;
    }
    
    return QCReportModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] == 'MATERIAL' ? QCType.material : QCType.pekerjaan,
      status: parsedStatus,
      staff: StaffIdentity.fromJson(json['staff'] ?? {}),
      location: ReportLocation.fromJson(json['location'] ?? {}),
      generalInfo: Map<String, String>.from(json['general_info'] ?? {}),
      checklistItems: (json['checklist_items'] as List? ?? [])
          .map((i) => QCChecklistAnswer.fromJson(i))
          .toList(),
      staffNote: json['staff_note'] ?? '',
      submittedAt: json['submitted_at'] != null 
          ? DateTime.parse(json['submitted_at']) 
          : DateTime.now(),
      adminReview: AdminReview.fromJson(json['admin_review'] ?? {}),
      generalPhotos: List<String>.from(json['general_photos'] ?? []),
      revisionNumber: json['revision_number'] ?? 1,
      revisionHistory: (json['revision_history'] as List? ?? [])
          .map((h) => QCReportModel.fromJson(h))
          .toList(),
      formCode: json['form_code'] ?? '',
      templateId: json['template_id'] ?? '',
    );
  }
}
