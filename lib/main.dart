import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/api_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart'; // 1. Import Sentry

// ... import file lu yang lain ...

// 2. Ubah main jadi asinkron
Future<void> main() async {
  // Wajib dipanggil sebelum runApp karena main() pake async
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Inisialisasi Sentry
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://849fa7632c73f664f8beb365d46a926c@o4511900970188800.ingest.us.sentry.io/4511901058990080';
      options.tracesSampleRate = 1.0; // Buat ngelacak performance UI lemot
    },
    appRunner: () => runApp(const MyApp()), 
  );
}
