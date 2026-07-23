import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/dummy/dummy_state.dart';
import 'package:mobile/features/profile/profile_photo_controller.dart';
import 'package:mobile/features/profile/screens/profile_screen.dart';
import 'package:mobile/shared/models/user_model.dart';

class _MemoryPersistence implements ProfilePhotoPersistence {
  final Map<String, Uint8List> values = {};

  @override
  Future<void> delete(String nik) async => values.remove(nik);

  @override
  Future<Uint8List?> read(String nik) async => values[nik];

  @override
  Future<void> write(String nik, Uint8List bytes) async {
    values[nik] = Uint8List.fromList(bytes);
  }
}

class _FakePicker implements ProfilePhotoPicker {
  XFile? result;
  ImageSource? lastSource;

  _FakePicker(this.result);

  @override
  Future<XFile?> pick(ImageSource source) async {
    lastSource = source;
    return result;
  }
}

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

XFile _image() =>
    XFile.fromData(_pngBytes, name: 'profile.png', mimeType: 'image/png');

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.camera_alt).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('legacy QA Staff profile displays Staff Warehouse', (
    tester,
  ) async {
    final state = DummyState();
    final originalUser = state.currentUser;
    state.currentUser = UserModel(
      id: originalUser.id,
      name: originalUser.name,
      role: 'QA Staff',
      nik: originalUser.nik,
      site: originalUser.site,
    );
    addTearDown(() => state.currentUser = originalUser);

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          photoPicker: _FakePicker(null),
          photoPersistence: _MemoryPersistence(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Staff Warehouse'), findsOneWidget);
    expect(find.text('QA Staff'), findsNothing);
  });

  testWidgets('gallery selection updates avatar with selected bytes', (
    tester,
  ) async {
    final picker = _FakePicker(_image());
    final persistence = _MemoryPersistence();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(photoPicker: picker, photoPersistence: persistence),
      ),
    );
    await tester.pump();
    await _openPicker(tester);
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();

    expect(picker.lastSource, ImageSource.gallery);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundImage, isA<MemoryImage>());
    expect(persistence.values[DummyState().currentUser.nik], _pngBytes);
  });

  test('stored identity photo is restored', () async {
    final persistence = _MemoryPersistence();
    final nik = DummyState().currentUser.nik;
    persistence.values[nik] = Uint8List.fromList(_pngBytes);
    final controller = ProfilePhotoController(
      nik: nik,
      picker: _FakePicker(null),
      persistence: persistence,
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.bytes, _pngBytes);
  });

  testWidgets('delete removes stored photo and restores default avatar', (
    tester,
  ) async {
    final persistence = _MemoryPersistence();
    final nik = DummyState().currentUser.nik;
    persistence.values[nik] = Uint8List.fromList(_pngBytes);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          photoPicker: _FakePicker(null),
          photoPersistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openPicker(tester);
    await tester.tap(find.text('Hapus Foto'));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundImage, isNull);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(persistence.values[nik], isNull);
  });

  testWidgets('cancel leaves current photo unchanged without error', (
    tester,
  ) async {
    final persistence = _MemoryPersistence();
    final nik = DummyState().currentUser.nik;
    final original = Uint8List.fromList(_pngBytes);
    persistence.values[nik] = original;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          photoPicker: _FakePicker(null),
          photoPersistence: persistence,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openPicker(tester);
    await tester.tap(find.text('Pilih dari Galeri'));
    await tester.pumpAndSettle();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(avatar.backgroundImage, isA<MemoryImage>());
    expect(persistence.values[nik], original);
    expect(find.textContaining('gagal'), findsNothing);
  });
}
