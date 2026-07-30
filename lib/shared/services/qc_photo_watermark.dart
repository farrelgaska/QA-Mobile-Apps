import 'package:image/image.dart' as image;

import '../models/qc_evidence_capture_metadata.dart';

class QCPhotoWatermark {
  static const String unavailableLocationText = 'Lokasi tidak tersedia';

  static List<String> lines(QCEvidenceCaptureMetadata metadata) {
    final capturedAt = DateTime.tryParse(metadata.capturedAt)?.toLocal();
    final date = capturedAt == null
        ? '-'
        : '${_twoDigits(capturedAt.day)}/${_twoDigits(capturedAt.month)}/${capturedAt.year.toString().padLeft(4, '0')}';
    final time = capturedAt == null
        ? '-'
        : '${_twoDigits(capturedAt.hour)}:${_twoDigits(capturedAt.minute)}:${_twoDigits(capturedAt.second)}';
    final result = <String>['Tanggal: $date', 'Waktu: $time'];
    final locationLabel = metadata.locationLabel?.trim();
    final latitude = _bounded(metadata.latitude, -90, 90);
    final longitude = _bounded(metadata.longitude, -180, 180);
    final hasCoordinates = latitude != null && longitude != null;
    final accuracy = metadata.accuracyMeters;
    final hasAccuracy = accuracy != null && accuracy.isFinite && accuracy >= 0;

    if (locationLabel != null && locationLabel.isNotEmpty) {
      result.add('Lokasi: $locationLabel');
    }
    if (hasCoordinates) {
      result.add(
        'Koordinat: ${latitude.toStringAsFixed(6)}, '
        '${longitude.toStringAsFixed(6)}',
      );
    }
    if (hasAccuracy) {
      result.add('Akurasi: ${_formatAccuracy(accuracy)} m');
    }
    if ((locationLabel == null || locationLabel.isEmpty) && !hasCoordinates) {
      result.add(unavailableLocationText);
    }
    return result;
  }

  static image.Image apply(
    image.Image source,
    QCEvidenceCaptureMetadata metadata,
  ) {
    final watermarkLines = lines(metadata);
    final shortestEdge = source.width < source.height
        ? source.width
        : source.height;
    final font = shortestEdge >= 1600
        ? image.arial48
        : shortestEdge >= 800
        ? image.arial24
        : image.arial14;
    final padding = (shortestEdge * 0.018).round().clamp(8, 48);
    final lineHeight = font.lineHeight > 0 ? font.lineHeight : font.base;
    final lineSpacing = (lineHeight * 0.22).round().clamp(2, 12);
    final panelHeight =
        (padding * 2) +
        (watermarkLines.length * lineHeight) +
        ((watermarkLines.length - 1) * lineSpacing);
    final panelTop = (source.height - panelHeight).clamp(0, source.height - 1);
    final maximumTextWidth = source.width - (padding * 2);

    image.fillRect(
      source,
      x1: 0,
      y1: panelTop,
      x2: source.width - 1,
      y2: source.height - 1,
      color: image.ColorRgba8(0, 0, 0, 178),
      alphaBlend: true,
    );

    var textY = panelTop + padding;
    for (final line in watermarkLines) {
      image.drawString(
        source,
        _fitLine(line, font, maximumTextWidth),
        font: font,
        x: padding,
        y: textY,
        color: image.ColorRgba8(255, 255, 255, 255),
      );
      textY += lineHeight + lineSpacing;
    }
    return source;
  }

  static String _fitLine(
    String value,
    image.BitmapFont font,
    int maximumWidth,
  ) {
    if (_textWidth(value, font) <= maximumWidth) return value;
    const suffix = '...';
    var end = value.length;
    while (end > 0 &&
        _textWidth('${value.substring(0, end)}$suffix', font) > maximumWidth) {
      end--;
    }
    return end == 0 ? suffix : '${value.substring(0, end)}$suffix';
  }

  static int _textWidth(String value, image.BitmapFont font) =>
      value.codeUnits.fold(0, (width, character) {
        final glyph = font.characters[character];
        return width + (glyph?.xAdvance ?? font.base ~/ 2);
      });

  static double? _bounded(double? value, double minimum, double maximum) =>
      value != null && value.isFinite && value >= minimum && value <= maximum
      ? value
      : null;

  static String _formatAccuracy(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
