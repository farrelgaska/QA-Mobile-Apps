/**
 * Idempotency-Key middleware.
 * Reads and validates the optional Idempotency-Key header.
 */
const AppError = require('../utils/AppError');
const { createHash } = require('crypto');

const MAX_IDEMPOTENCY_KEY_LENGTH = 255;

const idempotencyMiddleware = (req, _res, next) => {
  const raw = req.headers['idempotency-key'];
  if (raw === undefined) {
    req.idempotencyKey = null;
    return next();
  }

  const key = typeof raw === 'string' ? raw.trim() : '';
  if (key.length === 0 || key.length > MAX_IDEMPOTENCY_KEY_LENGTH) {
    return next(new AppError({
      status: 400,
      code: 'INVALID_IDEMPOTENCY_KEY',
      message: `Kunci pengiriman harus berisi 1 sampai ${MAX_IDEMPOTENCY_KEY_LENGTH} karakter.`
    }));
  }

  req.idempotencyKey = key;
  req.idempotencyKeyFingerprint = createHash('sha256')
    .update(key)
    .digest('hex')
    .slice(0, 16);
  next();
};

module.exports = idempotencyMiddleware;
module.exports.MAX_IDEMPOTENCY_KEY_LENGTH = MAX_IDEMPOTENCY_KEY_LENGTH;
