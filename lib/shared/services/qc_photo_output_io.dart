import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<XFile> createQCPhotoJpegOutput({
  required XFile source,
  required Uint8List bytes,
  required String outputName,
}) async {
  var outputDirectory = Directory.systemTemp;
  if (source.path.isNotEmpty) {
    final sourceDirectory = File(source.path).parent;
    if (await sourceDirectory.exists()) {
      outputDirectory = sourceDirectory;
    }
  }

  final outputFile = File(
    '${outputDirectory.path}${Platform.pathSeparator}$outputName',
  );
  try {
    await outputFile.writeAsBytes(bytes, flush: true);
  } catch (_) {
    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    rethrow;
  }

  return XFile(
    outputFile.path,
    name: outputName,
    mimeType: 'image/jpeg',
    length: bytes.length,
  );
}

Future<void> deleteQCPhotoJpegOutput(XFile photo) async {
  if (photo.path.isEmpty) return;
  final outputFile = File(photo.path);
  if (await outputFile.exists()) {
    await outputFile.delete();
  }
}
