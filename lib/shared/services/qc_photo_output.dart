import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'qc_photo_output_stub.dart'
    if (dart.library.io) 'qc_photo_output_io.dart'
    as platform;

Future<XFile> createQCPhotoJpegOutput({
  required XFile source,
  required Uint8List bytes,
  required String outputName,
}) {
  return platform.createQCPhotoJpegOutput(
    source: source,
    bytes: bytes,
    outputName: outputName,
  );
}

Future<void> deleteQCPhotoJpegOutput(XFile photo) {
  return platform.deleteQCPhotoJpegOutput(photo);
}
