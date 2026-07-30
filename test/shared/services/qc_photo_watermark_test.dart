import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/models/qc_evidence_capture_metadata.dart';
import 'package:mobile/shared/services/qc_photo_processor.dart';
import 'package:mobile/shared/services/qc_photo_watermark.dart';
import 'package:mobile/shared/utils/qc_photo_validation.dart';

void main() {
  test(
    'complete location watermark includes label, coordinates, and accuracy',
    () {
      final lines = QCPhotoWatermark.lines(
        _metadata(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracyMeters: 3.25,
          locationLabel: 'Gudang Utama',
        ),
      );

      expect(lines, contains('Lokasi: Gudang Utama'));
      expect(lines, contains('Koordinat: -6.208800, 106.845600'));
      expect(lines, contains('Akurasi: 3.25 m'));
      expect(lines, isNot(contains(QCPhotoWatermark.unavailableLocationText)));
    },
  );

  test('coordinates render without a location label', () {
    final lines = QCPhotoWatermark.lines(
      _metadata(latitude: -7.2575, longitude: 112.7521, accuracyMeters: 8),
    );

    expect(lines.where((line) => line.startsWith('Lokasi:')), isEmpty);
    expect(lines, contains('Koordinat: -7.257500, 112.752100'));
    expect(lines, contains('Akurasi: 8 m'));
    expect(lines, isNot(contains(QCPhotoWatermark.unavailableLocationText)));
  });

  test('missing valid location renders the unavailable fallback', () {
    final lines = QCPhotoWatermark.lines(_metadata());

    expect(lines, contains(QCPhotoWatermark.unavailableLocationText));
    expect(lines.where((line) => line.startsWith('Koordinat:')), isEmpty);
    expect(lines.where((line) => line.startsWith('Akurasi:')), isEmpty);
  });

  test('capture timestamp uses local date and time formatting', () {
    final localCapture = DateTime(2026, 7, 30, 14, 5, 9);
    final lines = QCPhotoWatermark.lines(
      QCEvidenceCaptureMetadata(
        capturedAt: QCEvidenceCaptureMetadata.iso8601WithTimezone(localCapture),
      ),
    );

    expect(lines.take(2), ['Tanggal: 30/07/2026', 'Waktu: 14:05:09']);
  });

  test(
    'watermarked final output is visible and remains at or below 2 MB',
    () async {
      final sourceImage = image.Image(width: 1200, height: 900)
        ..clear(image.ColorRgb8(235, 235, 235));
      final sourceBytes = Uint8List.fromList(
        image.encodeJpg(sourceImage, quality: 95),
      );
      final source = XFile.fromData(
        sourceBytes,
        name: 'watermark-source.jpg',
        mimeType: 'image/jpeg',
      );
      final processor = BoundedQCPhotoProcessor();

      final result = await processor.process(
        source,
        captureMetadata: _metadata(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracyMeters: 3.25,
          locationLabel: 'Gudang Utama',
        ),
      );
      addTearDown(() => processor.deleteGeneratedFile(result.file));
      final decoded = image.decodeJpg(result.bytes);

      expect(result.isGenerated, isTrue);
      expect(result.file.mimeType, 'image/jpeg');
      expect(result.bytes.length, lessThanOrEqualTo(maxQCPhotoSizeBytes));
      expect(decoded, isNotNull);
      final topPixel = decoded!.getPixel(10, 10);
      final bottomPixel = decoded.getPixel(10, decoded.height - 10);
      expect(_brightness(topPixel), greaterThan(200));
      expect(_brightness(bottomPixel), lessThan(150));
    },
  );
}

QCEvidenceCaptureMetadata _metadata({
  double? latitude,
  double? longitude,
  double? accuracyMeters,
  String? locationLabel,
}) => QCEvidenceCaptureMetadata(
  capturedAt: QCEvidenceCaptureMetadata.iso8601WithTimezone(
    DateTime(2026, 7, 30, 14, 5, 9),
  ),
  latitude: latitude,
  longitude: longitude,
  accuracyMeters: accuracyMeters,
  locationLabel: locationLabel,
);

double _brightness(image.Pixel pixel) =>
    (pixel.r.toDouble() + pixel.g.toDouble() + pixel.b.toDouble()) / 3;
