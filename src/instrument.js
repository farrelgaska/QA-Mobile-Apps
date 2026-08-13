// Import with `import * as Sentry from "@sentry/node"` if you are using ESM
const Sentry = require("@sentry/node");

Sentry.init({
  dsn: "https://c11ff5fe20bd9eaa3ac4bbf5cc29c7ff@o4511900970188800.ingest.us.sentry.io/4511900987359232",
  // Tracing
  tracesSampleRate: 1.0, //  Capture 100% of the transactions
  dataCollection: {
    // To disable sending user data and HTTP bodies, uncomment the lines below. For more info visit:
    // https://docs.sentry.io/platforms/javascript/guides/node/configuration/options/#dataCollection
    // userInfo: false,
    // httpBodies: [],
  },
});