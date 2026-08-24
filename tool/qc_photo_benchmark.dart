import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:mobile/shared/models/qc_evidence_capture_metadata.dart';
import 'package:mobile/shared/services/qc_photo_watermark.dart';
import 'package:mobile/shared/utils/qc_photo_validation.dart';

const _metadata = QCEvidenceCaptureMetadata(
  capturedAt: '2026-08-24T10:15:30+07:00',
  latitude: -6.2088,
  longitude: 106.8456,
  accuracyMeters: 4.5,
  locationLabel: 'Gudang Utama',
);

void main(List<String> arguments) {
  final mode = arguments.firstOrNull ?? 'baseline';
  final config = switch (mode) {
    'baseline' => const _Config(
        maximumLongEdge: 1920,
        interpolation: image.Interpolation.average,
      ),
    'picker1920' => const _Config(
        maximumLongEdge: 1920,
        interpolation: image.Interpolation.average,
        pickerLongEdge: 1920,
        skipDuplicateQuality: true,
      ),
    _ => throw ArgumentError.value(mode, 'mode'),
  };
  final directory = Directory.systemTemp.createTempSync('qc_photo_benchmark_');
  try {
    final fixtures = [
      _createFixture(directory, config, 'small', 1280, 960),
      _createFixture(directory, config, 'medium', 2560, 1920),
      _createFixture(directory, config, 'large', 4032, 3024),
    ];
    _run(fixtures.first, config, directory, -1);
    stdout.writeln('mode=$mode runs=3');
    stdout.writeln(
      'fixture,source_dimensions,input_dimensions,input_bytes,'
      'output_dimensions,output_bytes,'
      'read_ms,decode_ms,resize_ms,watermark_ms,encode_ms,write_ms,total_ms',
    );
    for (final fixture in fixtures) {
      final runs = [
        for (var run = 0; run < 3; run++) _run(fixture, config, directory, run),
      ];
      runs.sort((a, b) => a.total.compareTo(b.total));
      stdout.writeln(runs[1].csv);
    }
  } finally {
    directory.deleteSync(recursive: true);
  }
}

_Fixture _createFixture(
  Directory directory,
  _Config config,
  String name,
  int width,
  int height,
) {
  final pixels = Uint8List(width * height * 3);
  var state = 0x12345678;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      state = (1664525 * state + 1013904223) & 0xffffffff;
      final offset = (y * width + x) * 3;
      final noise = state >> 27;
      pixels[offset] = ((x * 255 ~/ width) + noise).clamp(0, 255);
      pixels[offset + 1] = ((y * 255 ~/ height) + noise).clamp(0, 255);
      pixels[offset + 2] =
          ((x + y) * 127 ~/ (width + height) + noise).clamp(0, 255);
    }
  }
  var source = image.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    numChannels: 3,
  );
  final pickerLongEdge = config.pickerLongEdge;
  if (pickerLongEdge != null &&
      (source.width > pickerLongEdge || source.height > pickerLongEdge)) {
    source = image.copyResize(
      source,
      width: source.width >= source.height ? pickerLongEdge : null,
      height: source.height > source.width ? pickerLongEdge : null,
      interpolation: image.Interpolation.average,
    );
  }
  final bytes = Uint8List.fromList(image.encodeJpg(source, quality: 95));
  final file = File('${directory.path}${Platform.pathSeparator}$name.jpg')
    ..writeAsBytesSync(bytes, flush: true);
  return _Fixture(
    name,
    width,
    height,
    source.width,
    source.height,
    bytes.length,
    file,
  );
}

_Result _run(
  _Fixture fixture,
  _Config config,
  Directory directory,
  int run,
) {
  final total = Stopwatch()..start();
  final watch = Stopwatch()..start();
  final bytes = fixture.file.readAsBytesSync();
  final read = watch.elapsedMicroseconds;

  watch.reset();
  final decoded = image.decodeImage(bytes)!;
  var oriented = image.bakeOrientation(decoded);
  final decode = watch.elapsedMicroseconds;

  watch.reset();
  if (oriented.width > config.maximumLongEdge ||
      oriented.height > config.maximumLongEdge) {
    oriented = image.copyResize(
      oriented,
      width: oriented.width >= oriented.height ? config.maximumLongEdge : null,
      height: oriented.height > oriented.width ? config.maximumLongEdge : null,
      interpolation: config.interpolation,
    );
  }
  final resize = watch.elapsedMicroseconds;

  watch.reset();
  final watermarked = QCPhotoWatermark.apply(oriented, _metadata);
  final watermark = watch.elapsedMicroseconds;

  watch.reset();
  var encoded = Uint8List.fromList(image.encodeJpg(watermarked, quality: 82));
  final fallbackQualities =
      config.skipDuplicateQuality ? const [70, 55] : const [82, 70, 55];
  for (final quality in fallbackQualities) {
    if (!exceedsQCPhotoSizeLimit(encoded)) break;
    encoded = Uint8List.fromList(
      image.encodeJpg(watermarked, quality: quality),
    );
  }
  final encode = watch.elapsedMicroseconds;

  watch.reset();
  final output = File(
    '${directory.path}${Platform.pathSeparator}${fixture.name}_$run.jpg',
  )..writeAsBytesSync(encoded, flush: true);
  final write = watch.elapsedMicroseconds;
  total.stop();

  return _Result(
    fixture: fixture,
    outputWidth: watermarked.width,
    outputHeight: watermarked.height,
    outputBytes: output.lengthSync(),
    read: read,
    decode: decode,
    resize: resize,
    watermark: watermark,
    encode: encode,
    write: write,
    total: total.elapsedMicroseconds,
  );
}

final class _Config {
  final int maximumLongEdge;
  final image.Interpolation interpolation;
  final int? pickerLongEdge;
  final bool skipDuplicateQuality;

  const _Config({
    required this.maximumLongEdge,
    required this.interpolation,
    this.pickerLongEdge,
    this.skipDuplicateQuality = false,
  });
}

final class _Fixture {
  final String name;
  final int width;
  final int height;
  final int inputWidth;
  final int inputHeight;
  final int bytes;
  final File file;

  const _Fixture(
    this.name,
    this.width,
    this.height,
    this.inputWidth,
    this.inputHeight,
    this.bytes,
    this.file,
  );
}

final class _Result {
  final _Fixture fixture;
  final int outputWidth;
  final int outputHeight;
  final int outputBytes;
  final int read;
  final int decode;
  final int resize;
  final int watermark;
  final int encode;
  final int write;
  final int total;

  const _Result({
    required this.fixture,
    required this.outputWidth,
    required this.outputHeight,
    required this.outputBytes,
    required this.read,
    required this.decode,
    required this.resize,
    required this.watermark,
    required this.encode,
    required this.write,
    required this.total,
  });

  String get csv => [
        fixture.name,
        '${fixture.width}x${fixture.height}',
        '${fixture.inputWidth}x${fixture.inputHeight}',
        fixture.bytes,
        '${outputWidth}x$outputHeight',
        outputBytes,
        _ms(read),
        _ms(decode),
        _ms(resize),
        _ms(watermark),
        _ms(encode),
        _ms(write),
        _ms(total),
      ].join(',');

  String _ms(int microseconds) => (microseconds / 1000).toStringAsFixed(1);
}
