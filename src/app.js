// 1. HARUS DIPANGGIL DI BARIS PERTAMA PALING ATAS!
require('./instrument');

const express = require('express');
const { LOCAL_QC_EVIDENCE_ROOT } = require('./storage/qc-evidence-storage');
let Sentry;
try {
  Sentry = require('@sentry/node');
} catch (_) {}
const cors = require('cors');
const { CORS_ORIGINS, CORS_ALLOW_LOCALHOST, APP_ENV } = require('./config/env');
const healthRoutes = require('./routes/health.routes');
const reportRoutes = require('./routes/report.routes');
const templateRoutes = require('./routes/template.routes');
const uploadRoutes = require('./routes/upload.routes');
const observabilityMiddleware = require('./middleware/observability');
const notFoundMiddleware = require('./middleware/not-found');
const errorHandlerMiddleware = require('./middleware/error-handler');
const demoAuthMiddleware = require('./middleware/auth');

const app = express();

app.use(observabilityMiddleware);

// CORS origin handler.
// - Explicit CORS_ORIGINS list is always checked.
// - Localhost (127.0.0.1 / localhost) is allowed only in development (CORS_ALLOW_LOCALHOST=true).
// - Staging and production must enumerate all allowed origins in CORS_ORIGINS explicitly.
// - The previous blanket *.vercel.app and localhost:* wildcards have been removed.
const isAllowedOrigin = (origin) => {
  if (!origin) return true; // same-origin / non-browser requests
  if (Array.isArray(CORS_ORIGINS)) {
    if (CORS_ORIGINS.includes('*') || CORS_ORIGINS.includes(origin)) return true;
  }
  if (CORS_ALLOW_LOCALHOST) {
    if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) return true;
  }
  return false;
};

app.use(cors({
  origin: (origin, callback) => {
    if (isAllowedOrigin(origin)) {
      callback(null, true);
    } else {
      callback(null, false);
    }
  },
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Idempotency-Key', 'X-Request-Id', 'Cache-Control'],
  exposedHeaders: ['Idempotency-Replayed', 'X-Request-Id'],
  credentials: true
}));

// Parse body limits to 2mb
app.use(express.json({ limit: '2mb' }));

// Root route identifying the API and version
app.get('/', (req, res) => {
  res.json({
    api: "QA Mobile Apps Mock API",
    version: "1.0.0",
    status: "running"
  });
});

// App routes
app.use('/health', healthRoutes);
app.use('/reports', demoAuthMiddleware, reportRoutes);
app.use('/templates', demoAuthMiddleware, templateRoutes);
app.use('/uploads', demoAuthMiddleware, uploadRoutes);
if (APP_ENV !== 'production') {
  app.use('/mock-storage', express.static(LOCAL_QC_EVIDENCE_ROOT));
}

// Fallbacks
app.use(notFoundMiddleware);

// 2. PASANG SENTRY ERROR HANDLER DI SINI (SEBELUM ERROR HANDLER UTAMA LU)
if (Sentry && typeof Sentry.setupExpressErrorHandler === 'function') {
  Sentry.setupExpressErrorHandler(app);
}

// Custom Error Handler Middleware lu
app.use(errorHandlerMiddleware);

module.exports = app;
