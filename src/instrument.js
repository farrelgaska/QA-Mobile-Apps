const {
  SENTRY_DSN: dsn,
  SENTRY_TRACES_SAMPLE_RATE
} = require('./config/env');

if (dsn) {
  try {
    const Sentry = require('@sentry/node');
    const configuredRate = Number(SENTRY_TRACES_SAMPLE_RATE);
    const tracesSampleRate = Number.isFinite(configuredRate) &&
      configuredRate >= 0 && configuredRate <= 1
      ? configuredRate
      : 0;
    Sentry.init({ dsn, tracesSampleRate });
  } catch (_) {
    // Local structured logs remain available when the optional integration fails.
  }
}
