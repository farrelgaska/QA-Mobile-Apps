const { randomUUID } = require('crypto');
const logger = require('../utils/logger');

const MAX_REQUEST_ID_LENGTH = 128;
const SAFE_REQUEST_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;

const createObservabilityMiddleware = ({
  log = logger,
  now = Date.now,
  createRequestId = randomUUID
} = {}) => (req, res, next) => {
  const incoming = req.get('x-request-id');
  const requestId = typeof incoming === 'string' &&
    incoming.length <= MAX_REQUEST_ID_LENGTH &&
    SAFE_REQUEST_ID_PATTERN.test(incoming)
    ? incoming
    : createRequestId();
  const startedAt = now();
  const requestPath = req.path;

  req.requestId = requestId;
  res.set('X-Request-Id', requestId);
  res.once('finish', () => {
    const fields = {
      request_id: requestId,
      method: req.method,
      path: requestPath,
      status: res.statusCode,
      duration_ms: Math.max(0, now() - startedAt)
    };
    if (requestPath === '/health' && res.statusCode < 400) {
      log.debug('http_request_completed', fields);
    } else if (res.statusCode >= 500) {
      log.error('http_request_completed', fields);
    } else if (res.statusCode >= 400) {
      log.warn('http_request_completed', fields);
    } else {
      log.info('http_request_completed', fields);
    }
  });

  next();
};

module.exports = createObservabilityMiddleware();
module.exports.createObservabilityMiddleware = createObservabilityMiddleware;
module.exports.MAX_REQUEST_ID_LENGTH = MAX_REQUEST_ID_LENGTH;
module.exports.SAFE_REQUEST_ID_PATTERN = SAFE_REQUEST_ID_PATTERN;
