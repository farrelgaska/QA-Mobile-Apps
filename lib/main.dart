import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/api_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.validateConfiguration();

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://849fa7632c73f664f8beb365d46a926c@o4511900970188800.ingest.us.sentry.io/4511901058990080';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(const MyApp()), 
  );
}
