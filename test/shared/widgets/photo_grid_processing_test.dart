import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/shared/models/qc_photo_processing_entry.dart';
import 'package:mobile/shared/widgets/photo_grid.dart';

void main() {
  testWidgets('shows immediate preview and HEIC processing placeholder', (
    tester,
  ) async {
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final previewEntry = QCPhotoProcessingEntry.fromCapture(
      id: 'jpeg-preview',
      source: XFile.fromData(
        pngBytes,
        name: 'capture.png',
        mimeType: 'image/png',
      ),
    );
    final heicEntry = QCPhotoProcessingEntry.fromCapture(
      id: 'heic-placeholder',
      source: XFile.fromData(
        Uint8List.fromList([0, 1, 2, 3]),
        name: 'capture.heic',
        mimeType: 'image/heic',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoGrid(
            photos: const [],
            processingPhotos: [previewEntry, heicEntry],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Memproses…'), findsOneWidget);
    expect(find.text('Memproses foto…'), findsOneWidget);
    expect(
      find.byKey(const Key('processing_photo_preview_jpeg-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('processing_photo_placeholder_heic-placeholder')),
      findsOneWidget,
    );
  });
}
