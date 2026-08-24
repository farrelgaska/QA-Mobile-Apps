const AppError = require('../utils/AppError');

const notFound = message => {
  return new AppError({
    status: 404,
    code: 'NOT_FOUND',
    message
  });
};

const conflict = (message, code = 'CONFLICT') => {
  return new AppError({
    status: 409,
    code,
    message
  });
};

const idempotencyConflict = () => {
  return new AppError({
    status: 409,
    code: 'IDEMPOTENCY_CONFLICT',
    message: 'Kunci pengiriman sudah digunakan untuk data yang berbeda.'
  });
};

const idempotencyReplayUnavailable = () => {
  return new AppError({
    status: 409,
    code: 'IDEMPOTENCY_REPLAY_UNAVAILABLE',
    message: 'Hasil pengiriman sebelumnya tidak lagi tersedia. Silakan coba lagi.'
  });
};

const idempotencyInProgress = () => {
  return new AppError({
    status: 409,
    code: 'IDEMPOTENCY_IN_PROGRESS',
    message: 'Pengiriman sebelumnya masih diproses. Silakan coba lagi.'
  });
};


const finalConclusionViolation = _message => {
  return new AppError({
    status: 422,
    code: 'UNPROCESSABLE_ENTITY',
    message: 'Kesimpulan akhir wajib diisi sebelum laporan dapat diselesaikan.'
  });
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
  return new AppError({
    status: 503,
    code: 'SERVICE_UNAVAILABLE',
    message: 'Layanan sementara tidak tersedia. Silakan coba lagi.',
    cause
  });
};

const internalError = cause => {
  return new AppError({
    status: 500,
    code: 'INTERNAL_ERROR',
    message: 'Terjadi kesalahan internal.',
    cause
  });
};

const translatePostgresError = (error, entity, id) => {
  if (isTransientPostgresError(error)) return databaseUnavailable(error);
  const entityLabel = entity.toLowerCase() === 'report' ? 'Laporan' : 'Template';
  if (error?.code === '23505') {
    if (entity.toLowerCase() === 'report' && error.constraint === 'qc_reports_pkey') {
      return conflict(`${entityLabel} dengan ID ${id} sudah ada.`, 'REPORT_ALREADY_EXISTS');
    }
    return conflict(`${entityLabel} dengan ID ${id} sudah ada.`, 'CONFLICT');
  }
  if (error?.code === '23503') {
    return conflict(`${entityLabel} bertentangan dengan data terkait.`, 'FOREIGN_KEY_CONFLICT');
  }
  if (error?.code === '57014') {
    return new AppError({
      status: 503,
      code: 'DATABASE_TIMEOUT',
      message: 'Permintaan melebihi batas waktu. Silakan coba lagi.',
      cause: error
    });
  }
  if (error?.code === '23514' &&
      /with status (?:NEEDS_FOLLOW_UP|APPROVED) requires an explicit final conclusion/.test(
        error.message || ''
      )) {
    return finalConclusionViolation(error.message);
  }
  if (error instanceof AppError) return error;
  return internalError(error);
};

module.exports = {
  notFound,
  conflict,
  idempotencyConflict,
  idempotencyReplayUnavailable,
  idempotencyInProgress,
  finalConclusionViolation,
  isTransientPostgresError,
  databaseUnavailable,
  translatePostgresError
};
