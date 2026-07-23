import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<XFile> createQCPhotoJpegOutput({
  required XFile source,
  required Uint8List bytes,
  required String outputName,
}) async {
  return XFile.fromData(
    bytes,
    name: outputName,
    mimeType: 'image/jpeg',
    length: bytes.length,
  );
}

Future<void> deleteQCPhotoJpegOutput(XFile photo) async {}
