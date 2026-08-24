const { ADMIN_DEMO_TOKEN } = require('../config/env');

/**
 * Demo-guard authentication middleware.
 *
 * When ADMIN_DEMO_TOKEN is configured, every request to a protected route
 * must supply the token via the Authorization header:
 *
 *   Authorization: Bearer <ADMIN_DEMO_TOKEN>
 *
 * If the token is not configured the middleware is a no-op (backward compatible
 * with local development without a token set).
 *
 * NOTE: This is NOT production-grade authentication. It is a lightweight access
 * guard for the demo/pilot phase only. Replace with a proper identity provider,
 * JWT verification, and role enforcement before production rollout.
 */
const demoAuthMiddleware = (req, res, next) => {
  if (!ADMIN_DEMO_TOKEN) {
    // Token not configured — allow all requests (local dev mode).
    return next();
  }

  const authHeader = req.headers['authorization'] ?? '';
  const token = authHeader.startsWith('Bearer ')
    ? authHeader.slice('Bearer '.length).trim()
    : null;

  if (token !== ADMIN_DEMO_TOKEN) {
    const AppError = require('../utils/AppError');
    return next(new AppError({
      status: 401,
      code: 'UNAUTHORIZED',
      message: 'Akses tidak sah. Silakan masuk kembali.'
    }));
  }

  next();
};

module.exports = demoAuthMiddleware;
