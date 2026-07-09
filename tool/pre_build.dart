import 'dart:io';

Future<void> main() async {
  await ensureSymlinkSupport();
}

Future<void> ensureSymlinkSupport() async {
  if (!Platform.isWindows) return;
  final temp = Directory.systemTemp.createTempSync();
  final src = Directory('${temp.path}\\src')..createSync();
  final link = Link('${temp.path}\\link');
  try {
    await link.create(src.path);
  } on FileSystemException catch (e) {
    if (e.osError?.errorCode == 1314) {
      stderr.writeln('❌ Developer Mode is disabled – enable it via start ms-settings:developers');
      exit(1);
    }
    rethrow;
  } finally {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  }
}
