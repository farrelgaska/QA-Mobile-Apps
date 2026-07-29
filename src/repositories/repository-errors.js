const notFound = message => {
  const error = new Error(message);
  error.statusCode = 404;
  return error;
};

const conflict = message => {
  const error = new Error(message);
  error.statusCode = 409;
  return error;
};

const finalConclusionViolation = message => {
  const error = new Error(message);
  error.statusCode = 422;
  return error;
};

const TRANSIENT_CONNECTION_CODES = new Set([
  'ECONNRESET',
  'ETIMEDOUT',
  'ECONNREFUSED',
  '57P01',
  '57P02',
  '57P03'
]);

const TRANSIENT_CONNECTION_MESSAGES = [
  /connection terminated due to connection timeout/i,
  /connection terminated unexpectedly/i,
  /connection (?:is )?closed/i,
  /timeout exceeded when trying to connect/i,
  /\bECONNRESET\b/i,
  /\bETIMEDOUT\b/i
];

const isTransientPostgresError = error => {
  const visited = new Set();
  let current = error;
  while (current && !visited.has(current)) {
    visited.add(current);
    const code = current.code?.toString();
    if (
      TRANSIENT_CONNECTION_CODES.has(code) ||
      code?.startsWith('08')
    ) {
      return true;
    }
    const message = current.message?.toString() || '';
    if (TRANSIENT_CONNECTION_MESSAGES.some(pattern => pattern.test(message))) {
      return true;
    }
    current = current.cause;
  }
  return false;
};

const databaseUnavailable = cause => {
  const error = new Error('Database temporarily unavailable. Please try again.');
  error.statusCode = 503;
  error.code = 'DATABASE_UNAVAILABLE';
  error.cause = cause;
  return error;
};

const translatePostgresError = (error, entity, id) => {
  if (error?.code === '23505') return conflict(`${entity} with ID ${id} already exists`);
  if (error?.code === '23514' &&
      /with status (?:NEEDS_FOLLOW_UP|APPROVED) requires an explicit final conclusion/.test(
        error.message || ''
      )) {
    return finalConclusionViolation(error.message);
  }
  return error;
};

module.exports = {
  notFound,
  conflict,
  finalConclusionViolation,
  isTransientPostgresError,
  databaseUnavailable,
  translatePostgresError
};
