try {
  const Sentry = require("@sentry/node");
  const dsn = process.env.SENTRY_DSN?.trim();
  if (dsn) {
    Sentry.init({
      dsn,
      tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE || 0),
    });
  }
} catch (e) {
  console.warn('[Sentry] Could not load @sentry/node:', e.message);
}
