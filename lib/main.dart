import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/api_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.validateConfiguration();
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isEmpty) {
    runApp(const MyApp());
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = double.tryParse(
            const String.fromEnvironment(
              'SENTRY_TRACES_SAMPLE_RATE',
              defaultValue: '0',
            ),
          ) ??
          0;
    },
    appRunner: () => runApp(const MyApp()),
  );
}
