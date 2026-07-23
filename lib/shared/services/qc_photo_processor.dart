import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../utils/qc_photo_validation.dart';

class QCPhotoProcessingException implements Exception {
  const QCPhotoProcessingException();
}

class QCProcessedPhoto {
  final XFile file;
  final Uint8List bytes;
  final bool isGenerated;

  const QCProcessedPhoto({
    required this.file,
    required this.bytes,
    required this.isGenerated,
  });
}

abstract class QCPhotoProcessor {
  Future<QCProcessedPhoto> process(XFile photo);

  Future<void> deleteGeneratedFile(XFile photo);
}

class BoundedQCPhotoProcessor implements QCPhotoProcessor {
  static const int _maximumLongEdge = 2560;
  static const int _minimumLongEdge = 1024;
  static const List<int> _jpegQualities = [88, 80, 72, 64, 56, 50];
  static const int _maximumDimensionSteps = 7;

  final Set<String> _generatedPaths = <String>{};

  @override
  Future<QCProcessedPhoto> process(XFile photo) async {
    final originalBytes = await photo.readAsBytes();
    if (!exceedsQCPhotoSizeLimit(originalBytes)) {
      return QCProcessedPhoto(
        file: photo,
        bytes: originalBytes,
        isGenerated: false,
      );
    }

    final processedBytes = await Isolate.run(
      () => _compressToLimit(originalBytes),
    );
    if (processedBytes == null || exceedsQCPhotoSizeLimit(processedBytes)) {
      throw const QCPhotoProcessingException();
    }

    final outputFile = await _createOutputFile(photo.path);
    try {
      await outputFile.writeAsBytes(processedBytes, flush: true);
    } catch (_) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      rethrow;
    }
    _generatedPaths.add(outputFile.path);
    final processedPhoto = XFile(
      outputFile.path,
      name: outputFile.uri.pathSegments.last,
      mimeType: 'image/jpeg',
      length: processedBytes.length,
    );
    return QCProcessedPhoto(
      file: processedPhoto,
      bytes: processedBytes,
      isGenerated: true,
    );
  }

  @override
  Future<void> deleteGeneratedFile(XFile photo) async {
    if (!_generatedPaths.remove(photo.path)) return;
    final file = File(photo.path);
    if (await file.exists()) await file.delete();
  }

  static Uint8List? _compressToLimit(Uint8List source) {
    final decoded = image.decodeImage(source);
    if (decoded == null) return null;

    final oriented = image.bakeOrientation(decoded);
    final originalLongEdge = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final safeMinimumLongEdge = originalLongEdge < _minimumLongEdge
        ? originalLongEdge
        : _minimumLongEdge;
    var longEdge = originalLongEdge > _maximumLongEdge
        ? _maximumLongEdge
        : originalLongEdge;

    for (
      var dimensionStep = 0;
      dimensionStep < _maximumDimensionSteps;
      dimensionStep++
    ) {
      final candidate = longEdge == originalLongEdge
          ? oriented
          : image.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? longEdge : null,
              height: oriented.height > oriented.width ? longEdge : null,
              interpolation: image.Interpolation.average,
            );

      for (final quality in _jpegQualities) {
        final encoded = Uint8List.fromList(
          image.encodeJpg(candidate, quality: quality),
        );
        if (!exceedsQCPhotoSizeLimit(encoded)) return encoded;
      }

      if (longEdge <= safeMinimumLongEdge) break;
      final reduced = (longEdge * 0.82).round();
      longEdge = reduced < safeMinimumLongEdge ? safeMinimumLongEdge : reduced;
    }
    return null;
  }

  Future<File> _createOutputFile(String sourcePath) async {
    final source = sourcePath.isEmpty ? null : File(sourcePath);
    final directory = source?.parent ?? Directory.systemTemp;
    final sourceName = source?.uri.pathSegments.last ?? 'camera_photo';
    final dotIndex = sourceName.lastIndexOf('.');
    final stem = (dotIndex > 0 ? sourceName.substring(0, dotIndex) : sourceName)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final suffix = DateTime.now().microsecondsSinceEpoch;
    return File(
      '${directory.path}${Platform.pathSeparator}${stem}_qc_$suffix.jpg',
    );
  }
}
