import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import 'qc_heic_converter.dart';
import 'qc_photo_output.dart';
import '../utils/qc_photo_validation.dart';

class QCPhotoProcessingException implements Exception {
  const QCPhotoProcessingException();
}

class QCPhotoDecodingException implements Exception {
  const QCPhotoDecodingException();
}

class QCPhotoInputMetadata {
  final String? mimeType;
  final String extension;
  final bool isHeicOrHeif;

  const QCPhotoInputMetadata({
    required this.mimeType,
    required this.extension,
    required this.isHeicOrHeif,
  });
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

  final QCHeicConverter _heicConverter;
  final Set<XFile> _generatedFiles = HashSet<XFile>.identity();

  BoundedQCPhotoProcessor({QCHeicConverter? heicConverter})
    : _heicConverter = heicConverter ?? const PlatformQCHeicConverter();

  @override
  Future<QCProcessedPhoto> process(XFile photo) async {
    final originalBytes = await photo.readAsBytes();
    final metadata = inspectInput(photo, originalBytes);

    var processableBytes = originalBytes;
    var requiresJpegOutput = false;
    if (metadata.isHeicOrHeif) {
      try {
        processableBytes = await _heicConverter.convertToJpeg(originalBytes);
      } catch (_) {
        throw const QCPhotoDecodingException();
      }
      if (!_isValidJpeg(processableBytes)) {
        throw const QCPhotoDecodingException();
      }
      final orientedJpeg = await compute(
        _normalizeConvertedJpeg,
        processableBytes,
      );
      if (orientedJpeg == null) {
        throw const QCPhotoDecodingException();
      }
      processableBytes = orientedJpeg;
      requiresJpegOutput = true;
    } else if (!_isDecodableImage(originalBytes)) {
      throw const QCPhotoDecodingException();
    }

    if (!exceedsQCPhotoSizeLimit(processableBytes) && !requiresJpegOutput) {
      return QCProcessedPhoto(
        file: photo,
        bytes: processableBytes,
        isGenerated: false,
      );
    }

    Uint8List finalBytes;
    if (!exceedsQCPhotoSizeLimit(processableBytes)) {
      finalBytes = processableBytes;
    } else {
      final processedBytes = await compute(_compressToLimit, processableBytes);
      if (processedBytes == null || exceedsQCPhotoSizeLimit(processedBytes)) {
        throw const QCPhotoProcessingException();
      }
      finalBytes = processedBytes;
    }

    if (!_isValidJpeg(finalBytes) || exceedsQCPhotoSizeLimit(finalBytes)) {
      throw const QCPhotoProcessingException();
    }

    final processedPhoto = await createQCPhotoJpegOutput(
      source: photo,
      bytes: finalBytes,
      outputName: _createOutputName(photo),
    );
    _generatedFiles.add(processedPhoto);
    return QCProcessedPhoto(
      file: processedPhoto,
      bytes: finalBytes,
      isGenerated: true,
    );
  }

  @override
  Future<void> deleteGeneratedFile(XFile photo) async {
    if (!_generatedFiles.remove(photo)) return;
    await deleteQCPhotoJpegOutput(photo);
  }

  static QCPhotoInputMetadata inspectInput(XFile photo, Uint8List bytes) {
    final mimeType = photo.mimeType
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final sourceName = photo.name.isNotEmpty ? photo.name : photo.path;
    final dotIndex = sourceName.lastIndexOf('.');
    final extension = dotIndex < 0
        ? ''
        : sourceName.substring(dotIndex).toLowerCase();
    final isHeicOrHeif =
        _heicMimeTypes.contains(mimeType) ||
        _heicExtensions.contains(extension) ||
        _hasHeicContainerSignature(bytes);
    return QCPhotoInputMetadata(
      mimeType: mimeType,
      extension: extension,
      isHeicOrHeif: isHeicOrHeif,
    );
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

  static Uint8List? _normalizeConvertedJpeg(Uint8List source) {
    try {
      final decoded = image.decodeJpg(source);
      if (decoded == null) return null;
      final oriented = image.bakeOrientation(decoded);
      return Uint8List.fromList(image.encodeJpg(oriented, quality: 92));
    } catch (_) {
      return null;
    }
  }

  static bool _isValidJpeg(Uint8List bytes) {
    if (bytes.length < 3 ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[2] != 0xff) {
      return false;
    }
    try {
      return image.decodeJpg(bytes) != null;
    } catch (_) {
      return false;
    }
  }

  static bool _isDecodableImage(Uint8List bytes) {
    try {
      return image.decodeImage(bytes) != null;
    } catch (_) {
      return false;
    }
  }

  static bool _hasHeicContainerSignature(Uint8List bytes) {
    if (bytes.length < 12 ||
        bytes[4] != 0x66 ||
        bytes[5] != 0x74 ||
        bytes[6] != 0x79 ||
        bytes[7] != 0x70) {
      return false;
    }

    final signatureLength = bytes.length < 64 ? bytes.length : 64;
    for (var offset = 8; offset + 3 < signatureLength; offset += 4) {
      final brand = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      if (_heicBrands.contains(brand)) return true;
    }
    return false;
  }

  static String _createOutputName(XFile source) {
    final sourceName = source.name.isNotEmpty ? source.name : 'camera_photo';
    final dotIndex = sourceName.lastIndexOf('.');
    final stem = (dotIndex > 0 ? sourceName.substring(0, dotIndex) : sourceName)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final suffix = DateTime.now().microsecondsSinceEpoch;
    return '${stem}_qc_$suffix.jpg';
  }

  static const Set<String> _heicMimeTypes = {
    'image/heic',
    'image/heif',
    'image/heic-sequence',
    'image/heif-sequence',
    'image/x-heic',
    'image/x-heif',
  };
  static const Set<String> _heicExtensions = {
    '.heic',
    '.heif',
    '.heics',
    '.heifs',
  };
  static const Set<String> _heicBrands = {
    'heic',
    'heix',
    'hevc',
    'hevx',
    'heim',
    'heis',
    'heif',
  };
}
