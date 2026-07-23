import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/services/qc_heic_converter.dart';
import 'package:mobile/shared/services/qc_photo_processor.dart';
import 'package:mobile/shared/utils/qc_photo_validation.dart';

void main() {
  test('web output keeps converted HEIC as a readable portrait JPEG', () async {
    final portraitJpeg = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 12, height: 20), quality: 92),
    );
    final processor = BoundedQCPhotoProcessor(
      heicConverter: _WebFakeHeicConverter(portraitJpeg),
    );
    final capture = XFile.fromData(
      _heicHeader(),
      name: 'iphone-capture.heic',
      mimeType: 'image/heic',
    );

    final result = await processor.process(capture);
    addTearDown(() => processor.deleteGeneratedFile(result.file));
    final outputBytes = await result.file.readAsBytes();
    final decoded = image.decodeJpg(outputBytes);

    expect(result.isGenerated, isTrue);
    expect(result.file.name, endsWith('.jpg'));
    expect(result.file.mimeType, 'image/jpeg');
    expect(outputBytes.length, lessThanOrEqualTo(maxQCPhotoSizeBytes));
    expect(decoded, isNotNull);
    expect(decoded!.width, 12);
    expect(decoded.height, 20);
  });
}

final class _WebFakeHeicConverter implements QCHeicConverter {
  final Uint8List output;

  const _WebFakeHeicConverter(this.output);

  @override
  Future<Uint8List> convertToJpeg(Uint8List heicBytes) async => output;
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
