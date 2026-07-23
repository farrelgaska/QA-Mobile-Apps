import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/services/qc_heic_converter.dart';
import 'package:mobile/shared/services/qc_photo_processor.dart';
import 'package:mobile/shared/utils/qc_photo_validation.dart';

void main() {
  late BoundedQCPhotoProcessor processor;

  setUp(() {
    processor = BoundedQCPhotoProcessor();
  });

  test('keeps an image already below 2 MB without recompression', () async {
    final bytes = _jpeg(width: 32, height: 24);
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

  test('keeps a valid PNG capture unchanged', () async {
    final bytes = Uint8List.fromList(
      image.encodePng(image.Image(width: 32, height: 24)),
    );
    final original = XFile.fromData(
      bytes,
      name: 'capture.png',
      mimeType: 'image/png',
    );

    final result = await processor.process(original);

    expect(result.file, same(original));
    expect(result.bytes, bytes);
    expect(result.isGenerated, isFalse);
  });

  test('converts HEIC input to JPEG before returning it', () async {
    final converted = _jpeg(width: 24, height: 40);
    final converter = _FakeHeicConverter(converted);
    processor = BoundedQCPhotoProcessor(heicConverter: converter);
    final metadataPhoto = XFile(
      'IMG_1234.HEIC',
      name: 'IMG_1234.HEIC',
      mimeType: 'image/heic',
    );
    final original = XFile.fromData(
      _heicHeader(),
      name: 'IMG_1234.HEIC',
      mimeType: 'image/heic',
    );
    final metadata = BoundedQCPhotoProcessor.inspectInput(
      metadataPhoto,
      _heicHeader(),
    );

    final result = await processor.process(original);
    addTearDown(() => processor.deleteGeneratedFile(result.file));

    expect(metadata.mimeType, 'image/heic');
    expect(metadata.extension, '.heic');
    expect(metadata.isHeicOrHeif, isTrue);
    expect(converter.callCount, 1);
    expect(result.isGenerated, isTrue);
    expect(result.file.name, endsWith('.jpg'));
    expect(result.file.mimeType, 'image/jpeg');
    expect(image.decodeJpg(result.bytes), isNotNull);
    expect(result.bytes.length, lessThanOrEqualTo(maxQCPhotoSizeBytes));
  });

  test('preserves converted HEIC orientation', () async {
    final portraitJpeg = _orientedJpeg(width: 50, height: 30, orientation: 6);
    processor = BoundedQCPhotoProcessor(
      heicConverter: _FakeHeicConverter(portraitJpeg),
    );
    final original = XFile.fromData(
      _heicHeader(),
      name: 'portrait.heif',
      mimeType: 'image/heif',
    );

    final result = await processor.process(original);
    addTearDown(() => processor.deleteGeneratedFile(result.file));
    final decoded = image.decodeJpg(result.bytes);

    expect(decoded, isNotNull);
    expect(decoded!.width, 30);
    expect(decoded.height, 50);
  });

  test('detects HEIC by container signature when metadata is wrong', () async {
    final converter = _FakeHeicConverter(_jpeg(width: 20, height: 20));
    processor = BoundedQCPhotoProcessor(heicConverter: converter);
    final original = XFile.fromData(
      _heicHeader(),
      name: 'camera-image.bin',
      mimeType: 'application/octet-stream',
    );

    final result = await processor.process(original);
    addTearDown(() => processor.deleteGeneratedFile(result.file));

    expect(converter.callCount, 1);
    expect(result.file.mimeType, 'image/jpeg');
  });

  test('compressed HEIC output never exceeds 2 MB', () async {
    final oversizedJpeg = _largeNoiseJpeg();
    expect(oversizedJpeg.length, greaterThan(maxQCPhotoSizeBytes));
    processor = BoundedQCPhotoProcessor(
      heicConverter: _FakeHeicConverter(oversizedJpeg),
    );
    final original = XFile.fromData(
      _heicHeader(),
      name: 'large.heic',
      mimeType: 'image/heic',
    );

    final result = await processor.process(original);
    addTearDown(() => processor.deleteGeneratedFile(result.file));

    expect(result.bytes.length, lessThanOrEqualTo(maxQCPhotoSizeBytes));
    expect(image.decodeJpg(result.bytes), isNotNull);
  });

  test('failed HEIC conversion does not produce a photo', () async {
    final converter = _FakeHeicConverter(
      Uint8List(0),
      failure: StateError('conversion failed'),
    );
    processor = BoundedQCPhotoProcessor(heicConverter: converter);
    final original = XFile.fromData(
      _heicHeader(),
      name: 'broken.heic',
      mimeType: 'image/heic',
    );

    await expectLater(
      processor.process(original),
      throwsA(isA<QCPhotoDecodingException>()),
    );
    expect(converter.callCount, 1);
  });

  test('rejects corrupt images even when below 2 MB', () async {
    final invalid = XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      name: 'invalid.jpg',
      mimeType: 'image/jpeg',
    );

    await expectLater(
      processor.process(invalid),
      throwsA(isA<QCPhotoDecodingException>()),
    );
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
        throwsA(isA<QCPhotoDecodingException>()),
      );
    },
  );
}

final class _FakeHeicConverter implements QCHeicConverter {
  final Uint8List output;
  final Object? failure;
  int callCount = 0;

  _FakeHeicConverter(this.output, {this.failure});

  @override
  Future<Uint8List> convertToJpeg(Uint8List heicBytes) async {
    callCount++;
    if (failure case final failure?) throw failure;
    return output;
  }
}

Uint8List _jpeg({required int width, required int height}) {
  return Uint8List.fromList(
    image.encodeJpg(image.Image(width: width, height: height), quality: 92),
  );
}

Uint8List _orientedJpeg({
  required int width,
  required int height,
  required int orientation,
}) {
  final source = image.Image(width: width, height: height);
  source.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(image.encodeJpg(source, quality: 92));
}

Uint8List _heicHeader() {
  return Uint8List.fromList([
    0x00,
    0x00,
    0x00,
    0x18,
    0x66,
    0x74,
    0x79,
    0x70,
    0x68,
    0x65,
    0x69,
    0x63,
    0x00,
    0x00,
    0x00,
    0x00,
    0x6d,
    0x69,
    0x66,
    0x31,
    0x68,
    0x65,
    0x69,
    0x63,
  ]);
}

Uint8List _largeNoiseJpeg() {
  const width = 1800;
  const height = 1400;
  final pixels = Uint8List(width * height * 3);
  var state = 0x2468ace0;
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
  return Uint8List.fromList(image.encodeJpg(source, quality: 100));
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
