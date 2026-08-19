import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'qc_evidence_capture_metadata.dart';

class QCPhotoProcessingEntry {
  final String id;
  final XFile source;
  final QCEvidenceCaptureMetadata? captureMetadata;
  final bool canPreviewSource;
  final Future<Uint8List>? previewBytes;

  QCPhotoProcessingEntry._({
    required this.id,
    required this.source,
    this.captureMetadata,
    required this.canPreviewSource,
    required this.previewBytes,
  });

  factory QCPhotoProcessingEntry.fromCapture({
    required String id,
    required XFile source,
    QCEvidenceCaptureMetadata? captureMetadata,
  }) {
    final mimeType = source.mimeType?.split(';').first.trim().toLowerCase();
    final sourceName = source.name.isNotEmpty ? source.name : source.path;
    final dotIndex = sourceName.lastIndexOf('.');
    final extension =
        dotIndex < 0 ? '' : sourceName.substring(dotIndex).toLowerCase();
    final isHeicOrHeif = const {
          'image/heic',
          'image/heif',
          'image/heic-sequence',
          'image/heif-sequence',
          'image/x-heic',
          'image/x-heif',
        }.contains(mimeType) ||
        const {'.heic', '.heif', '.heics', '.heifs'}.contains(extension);
    final canPreviewSource = !isHeicOrHeif &&
        (const {'image/jpeg', 'image/png'}.contains(mimeType) ||
            const {'.jpg', '.jpeg', '.png'}.contains(extension));

    return QCPhotoProcessingEntry._(
      id: id,
      source: source,
      captureMetadata: captureMetadata,
      canPreviewSource: canPreviewSource,
      previewBytes: canPreviewSource ? source.readAsBytes() : null,
    );
  }

  String get processingLabel =>
      canPreviewSource ? 'Memproses…' : 'Memproses foto…';
}
