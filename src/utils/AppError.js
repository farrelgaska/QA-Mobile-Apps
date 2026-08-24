class AppError extends Error {
  constructor({ status = 500, code = 'INTERNAL_ERROR', message = 'Terjadi kesalahan internal.', details = [], cause }) {
    super(message, { cause });
    this.name = this.constructor.name;
    this.status = status;
    this.statusCode = status;
    this.code = code;
    this.details = details;
  }
}

module.exports = AppError;
