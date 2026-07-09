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
      stderr.writeln('❌ Developer Mode is disabled.');
      stderr.writeln('👉 If using Win + R, type: ms-settings:developers');
      stderr.writeln('👉 If using PowerShell, run: start ms-settings:developers');
      try {
        await Process.run('explorer', ['ms-settings:developers']);
      } catch (_) {}
      exit(1);
    }
    rethrow;
  } finally {
    try {
      temp.deleteSync(recursive: true);
    } catch (_) {}
  }
}
