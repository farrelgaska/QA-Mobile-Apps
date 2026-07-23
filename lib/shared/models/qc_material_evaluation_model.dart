import 'dart:convert';

enum QCSampleEvaluationStatus { notEvaluated, withinStandard, outOfStandard }

extension QCSampleEvaluationStatusValue on QCSampleEvaluationStatus {
  String get apiValue => switch (this) {
    QCSampleEvaluationStatus.notEvaluated => 'NOT_EVALUATED',
    QCSampleEvaluationStatus.withinStandard => 'WITHIN_STANDARD',
    QCSampleEvaluationStatus.outOfStandard => 'OUT_OF_STANDARD',
  };

  String get displayLabel => switch (this) {
    QCSampleEvaluationStatus.notEvaluated => 'Belum Dievaluasi',
    QCSampleEvaluationStatus.withinStandard => 'Sesuai Standar',
    QCSampleEvaluationStatus.outOfStandard => 'Di Luar Standar',
  };
}

QCSampleEvaluationStatus qcSampleEvaluationStatusFromValue(dynamic value) {
  return switch (value?.toString().toUpperCase()) {
    'WITHIN_STANDARD' => QCSampleEvaluationStatus.withinStandard,
    'OUT_OF_STANDARD' => QCSampleEvaluationStatus.outOfStandard,
    _ => QCSampleEvaluationStatus.notEvaluated,
  };
}

class QCMaterialReviewRequest {
  static const requestedKey = 'qcReviewRequested';
  static const requestedAtKey = 'qcReviewRequestedAt';
  static const failedSampleIdsKey = 'qcReviewFailedSampleIds';
  static const failedSampleNumbersKey = 'qcReviewFailedSampleNumbers';

  final DateTime requestedAt;
  final List<String> failedSampleIds;
  final List<int> failedSampleNumbers;

  const QCMaterialReviewRequest({
    required this.requestedAt,
    required this.failedSampleIds,
    required this.failedSampleNumbers,
  });

  void writeToGeneralInfo(Map<String, String> generalInfo) {
    generalInfo[requestedKey] = 'true';
    generalInfo[requestedAtKey] = requestedAt.toIso8601String();
    generalInfo[failedSampleIdsKey] = jsonEncode(failedSampleIds);
    generalInfo[failedSampleNumbersKey] = jsonEncode(failedSampleNumbers);
  }

  static QCMaterialReviewRequest? fromGeneralInfo(
    Map<String, String> generalInfo,
  ) {
    if (generalInfo[requestedKey]?.toLowerCase() != 'true') return null;
    final requestedAt = DateTime.tryParse(generalInfo[requestedAtKey] ?? '');
    if (requestedAt == null) return null;

    final ids = _stringList(generalInfo[failedSampleIdsKey]);
    final numbers = _intList(generalInfo[failedSampleNumbersKey]);
    if (ids.isEmpty && numbers.isEmpty) return null;

    return QCMaterialReviewRequest(
      requestedAt: requestedAt,
      failedSampleIds: List.unmodifiable(ids),
      failedSampleNumbers: List.unmodifiable(numbers),
    );
  }

  static List<String> _stringList(String? value) {
    try {
      return (jsonDecode(value ?? '') as List)
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static List<int> _intList(String? value) {
    try {
      return (jsonDecode(value ?? '') as List)
          .map((entry) => entry is int ? entry : int.tryParse('$entry'))
          .whereType<int>()
          .where((entry) => entry > 0)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
