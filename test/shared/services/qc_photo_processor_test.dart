import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/services/qc_photo_processor.dart';
import 'package:mobile/shared/utils/qc_photo_validation.dart';

void main() {
  late BoundedQCPhotoProcessor processor;

  setUp(() {
    processor = BoundedQCPhotoProcessor();
  });

  test('keeps an image already below 2 MB without recompression', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final original = XFile.fromData(
      bytes,
      name: 'small.jpg',
      mimeType: 'image/jpeg',
    );

    final result = await processor.process(original);

    expect(result.file, same(original));
    expect(result.bytes, bytes);
    expect(result.isGenerated, isFalse);
  });

  test('compresses an image above 2 MB and never exceeds the limit', () async {
    final source = _largeNoiseBitmap();
    expect(source.length, greaterThan(maxQCPhotoSizeBytes));
    final original = XFile.fromData(
      source,
      name: 'large.bmp',
      mimeType: 'image/bmp',
    );

    final result = await processor.process(original);
    addTearDown(() => processor.deleteGeneratedFile(result.file));

    expect(result.isGenerated, isTrue);
    expect(result.file.path, isNotEmpty);
    expect(await result.file.length(), lessThanOrEqualTo(maxQCPhotoSizeBytes));
    expect(result.bytes.length, lessThanOrEqualTo(maxQCPhotoSizeBytes));
    expect(image.decodeImage(result.bytes), isNotNull);
  });

  test(
    'fails safely when an oversized file is not a decodable image',
    () async {
      final invalid = XFile.fromData(
        Uint8List(maxQCPhotoSizeBytes + 1),
        name: 'invalid.jpg',
        mimeType: 'image/jpeg',
      );

      await expectLater(
        processor.process(invalid),
        throwsA(isA<QCPhotoProcessingException>()),
      );
    },
  );
}

Uint8List _largeNoiseBitmap() {
  const width = 1800;
  const height = 1400;
  final pixels = Uint8List(width * height * 3);
  var state = 0x12345678;
  for (var index = 0; index < pixels.length; index++) {
    state = (1664525 * state + 1013904223) & 0xffffffff;
    pixels[index] = state >> 24;
  }
  final source = image.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    numChannels: 3,
  );
  return Uint8List.fromList(image.encodeBmp(source));
}
