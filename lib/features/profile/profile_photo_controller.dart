import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ProfilePhotoPicker {
  Future<XFile?> pick(ImageSource source);
}

class DeviceProfilePhotoPicker implements ProfilePhotoPicker {
  final ImagePicker _picker;

  DeviceProfilePhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  @override
  Future<XFile?> pick(ImageSource source) => _picker.pickImage(
    source: source,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 75,
    requestFullMetadata: false,
  );
}

abstract class ProfilePhotoPersistence {
  Future<Uint8List?> read(String nik);
  Future<void> write(String nik, Uint8List bytes);
  Future<void> delete(String nik);
}

class PreferencesProfilePhotoPersistence implements ProfilePhotoPersistence {
  String _key(String nik) => 'profile_photo_bytes_$nik';

  @override
  Future<Uint8List?> read(String nik) async {
    final value = (await SharedPreferences.getInstance()).getString(_key(nik));
    if (value == null) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String nik, Uint8List bytes) async {
    await (await SharedPreferences.getInstance()).setString(
      _key(nik),
      base64Encode(bytes),
    );
  }

  @override
  Future<void> delete(String nik) async {
    await (await SharedPreferences.getInstance()).remove(_key(nik));
  }
}

enum ProfilePhotoSelection { updated, cancelled }

class ProfilePhotoException implements Exception {
  final String message;
  const ProfilePhotoException(this.message);
}

class ProfilePhotoController extends ChangeNotifier {
  static const maxBytes = 2 * 1024 * 1024;
  static const supportedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const supportedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  final String nik;
  final ProfilePhotoPicker picker;
  final ProfilePhotoPersistence persistence;
  Uint8List? _bytes;
  bool _disposed = false;

  ProfilePhotoController({
    required this.nik,
    ProfilePhotoPicker? picker,
    ProfilePhotoPersistence? persistence,
  }) : picker = picker ?? DeviceProfilePhotoPicker(),
       persistence = persistence ?? PreferencesProfilePhotoPersistence();

  Uint8List? get bytes => _bytes;
  bool get hasPhoto => _bytes != null;

  Future<void> restore() async {
    final stored = await persistence.read(nik);
    if (_disposed) return;
    _bytes = stored;
    notifyListeners();
  }

  Future<ProfilePhotoSelection> select(ImageSource source) async {
    final file = await picker.pick(source);
    if (file == null) return ProfilePhotoSelection.cancelled;
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = file.mimeType?.toLowerCase();
    final isSupported = mimeType != null
        ? supportedMimeTypes.contains(mimeType)
        : supportedExtensions.contains(extension);
    if (!isSupported) {
      throw const ProfilePhotoException(
        'Format foto tidak didukung. Gunakan JPG, PNG, atau WEBP.',
      );
    }
    final selectedBytes = await file.readAsBytes();
    if (selectedBytes.isEmpty || selectedBytes.length > maxBytes) {
      throw const ProfilePhotoException(
        'Ukuran foto terlalu besar. Pilih foto maksimal 2 MB.',
      );
    }
    await persistence.write(nik, selectedBytes);
    if (_disposed) return ProfilePhotoSelection.cancelled;
    _bytes = selectedBytes;
    notifyListeners();
    return ProfilePhotoSelection.updated;
  }

  Future<void> remove() async {
    await persistence.delete(nik);
    if (_disposed) return;
    _bytes = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
