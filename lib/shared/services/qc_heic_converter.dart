import 'dart:typed_data';

import 'package:heic_to_png_jpg/heic_to_png_jpg.dart';

abstract interface class QCHeicConverter {
  Future<Uint8List> convertToJpeg(Uint8List heicBytes);
}

final class PlatformQCHeicConverter implements QCHeicConverter {
  const PlatformQCHeicConverter();

  @override
  Future<Uint8List> convertToJpeg(Uint8List heicBytes) {
    return HeicConverter.convertToJPG(
      heicData: heicBytes,
      quality: 100,
    );
  }
}
