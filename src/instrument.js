try {
  const Sentry = require("@sentry/node");
  Sentry.init({
    dsn: "https://c11ff5fe20bd9eaa3ac4bbf5cc29c7ff@o4511900970188800.ingest.us.sentry.io/4511900987359232",
    tracesSampleRate: 1.0,
  });
} catch (e) {
  console.warn('[Sentry] Could not load @sentry/node:', e.message);
}