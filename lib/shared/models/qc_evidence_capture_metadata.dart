class QCEvidenceCaptureMetadata {
  final String capturedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? locationLabel;

  const QCEvidenceCaptureMetadata({
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.locationLabel,
  });

  bool get hasLocation =>
      latitude != null && longitude != null && accuracyMeters != null;

  Map<String, dynamic> toJson() => {
        'capturedAt': capturedAt,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'locationLabel': locationLabel,
      };

  factory QCEvidenceCaptureMetadata.fromJson(Map<String, dynamic> json) {
    return QCEvidenceCaptureMetadata(
      capturedAt: json['capturedAt']?.toString() ?? '',
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      accuracyMeters: _asDouble(json['accuracyMeters']),
      locationLabel: _nonEmptyString(json['locationLabel']),
    );
  }

  static String iso8601WithTimezone(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteMinutes = offset.inMinutes.abs();
    final hours = (absoluteMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (absoluteMinutes % 60).toString().padLeft(2, '0');
    return '${local.toIso8601String()}$sign$hours:$minutes';
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _nonEmptyString(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
