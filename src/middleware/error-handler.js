const AppError = require('../utils/AppError');
const logger = require('../utils/logger');
const { APP_ENV } = require('../config/env');

const createErrorHandler = ({ log = logger, environment = APP_ENV } = {}) =>
  (err, req, res, next) => {
    const status = err instanceof AppError ? err.status : (err.statusCode || 500);
    const code = err instanceof AppError
      ? err.code
      : ({
          400: 'BAD_REQUEST',
          404: 'NOT_FOUND',
          409: 'CONFLICT',
          413: 'PAYLOAD_TOO_LARGE',
          415: 'UNSUPPORTED_MEDIA_TYPE',
          422: 'UNPROCESSABLE_ENTITY'
        }[status] || 'INTERNAL_ERROR');
    const message = err instanceof AppError
      ? err.message
      : (status >= 500 ? 'Terjadi kesalahan internal.' : (err.message || 'Terjadi kesalahan.'));

    const event = code === 'IDEMPOTENCY_CONFLICT'
      ? 'idempotency_conflict'
      : 'request_failed';
    const fields = {
      request_id: req.requestId || null,
      method: req.method,
      path: req.path,
      status,
      code,
      ...(req.observability || {}),
      ...(req.idempotencyKeyFingerprint
        ? { idempotency_key_fingerprint: req.idempotencyKeyFingerprint }
        : {})
    };
    if (status >= 500) {
      fields.error_name = err.name || 'Error';
      fields.cause_code = err.cause?.code || err.code || null;
      if (environment !== 'production' && typeof err.stack === 'string') {
        fields.stack = err.stack;
      }
      log.error(event, fields);
    } else {
      log.warn(event, fields);
    }

    res.status(status).json({
      code,
      message,
      status,
      // Existing Mobile/Web clients still read this field; remove after both migrate.
      error: { code, message }
    });
  };

module.exports = createErrorHandler();
module.exports.createErrorHandler = createErrorHandler;
