// 1. HARUS DIPANGGIL DI BARIS PERTAMA PALING ATAS!
require('./instrument');

const express = require('express');
const Sentry = require('@sentry/node'); // Import Sentry SDK
const cors = require('cors');
const { CORS_ORIGINS } = require('./config/env');
const healthRoutes = require('./routes/health.routes');
const reportRoutes = require('./routes/report.routes');
const templateRoutes = require('./routes/template.routes');
const uploadRoutes = require('./routes/upload.routes');
const notFoundMiddleware = require('./middleware/not-found');
const errorHandlerMiddleware = require('./middleware/error-handler');

const app = express();

// Configure CORS
app.use(cors({
  origin: CORS_ORIGINS,
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
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
app.use('/reports', reportRoutes);
app.use('/templates', templateRoutes);
app.use('/uploads', uploadRoutes);

// Fallbacks
app.use(notFoundMiddleware);

// 2. PASANG SENTRY ERROR HANDLER DI SINI (SEBELUM ERROR HANDLER UTAMA LU)
Sentry.setupExpressErrorHandler(app);

// Custom Error Handler Middleware lu
app.use(errorHandlerMiddleware);

module.exports = app;