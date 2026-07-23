import 'qc_checklist_answer_model.dart';

enum QCSampleInspectionStatus { notStarted, inProgress, completed }

extension QCSampleInspectionStatusValue on QCSampleInspectionStatus {
  String get apiValue => switch (this) {
    QCSampleInspectionStatus.notStarted => 'NOT_STARTED',
    QCSampleInspectionStatus.inProgress => 'IN_PROGRESS',
    QCSampleInspectionStatus.completed => 'COMPLETED',
  };
}

class QCReportSample {
  final String id;
  final int sampleNumber;
  final QCSampleInspectionStatus inspectionStatus;
  final List<QCChecklistAnswer> checklistAnswers;
  final String notes;
  final List<String> photoPaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QCReportSample({
    required this.id,
    required this.sampleNumber,
    required this.inspectionStatus,
    required this.checklistAnswers,
    required this.notes,
    required this.photoPaths,
    required this.createdAt,
    required this.updatedAt,
  });

  QCReportSample copyWith({
    String? id,
    int? sampleNumber,
    QCSampleInspectionStatus? inspectionStatus,
    List<QCChecklistAnswer>? checklistAnswers,
    String? notes,
    List<String>? photoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QCReportSample(
      id: id ?? this.id,
      sampleNumber: sampleNumber ?? this.sampleNumber,
      inspectionStatus: inspectionStatus ?? this.inspectionStatus,
      checklistAnswers: checklistAnswers ?? this.checklistAnswers,
      notes: notes ?? this.notes,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sample_number': sampleNumber,
    'inspection_status': inspectionStatus.apiValue,
    'checklist_answers': checklistAnswers
        .map((answer) => answer.toSampleJson())
        .toList(growable: false),
    'notes': notes,
    'photo_paths': photoPaths,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory QCReportSample.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return QCReportSample(
      id: json['id']?.toString() ?? '',
      sampleNumber: _positiveInt(json['sample_number']) ?? 1,
      inspectionStatus: _statusFromJson(json['inspection_status']),
      checklistAnswers: (json['checklist_answers'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (answer) =>
                QCChecklistAnswer.fromJson(Map<String, dynamic>.from(answer)),
          )
          .toList(growable: false),
      notes: json['notes']?.toString() ?? '',
      photoPaths: List<String>.from(json['photo_paths'] ?? const []),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? now,
    );
  }

  static int? _positiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static QCSampleInspectionStatus _statusFromJson(dynamic value) {
    return switch (value?.toString().toUpperCase()) {
      'IN_PROGRESS' => QCSampleInspectionStatus.inProgress,
      'COMPLETED' => QCSampleInspectionStatus.completed,
      _ => QCSampleInspectionStatus.notStarted,
    };
  }
}
