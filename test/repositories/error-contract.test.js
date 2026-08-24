const { test } = require('node:test');
const assert = require('node:assert');
const { translatePostgresError } = require('../../src/repositories/repository-errors');
const AppError = require('../../src/utils/AppError');
const errorHandler = require('../../src/middleware/error-handler');

test('Error Mapping - Maps Postgres 23505 with qc_reports_pkey to REPORT_ALREADY_EXISTS', () => {
  const mockPgError = new Error('duplicate key value violates unique constraint "qc_reports_pkey"');
  mockPgError.code = '23505';
  mockPgError.constraint = 'qc_reports_pkey';

  const appError = translatePostgresError(mockPgError, 'Report', '123');

  assert.strictEqual(appError.code, 'REPORT_ALREADY_EXISTS');
  assert.strictEqual(appError.status, 409);
  assert.strictEqual(appError.message, 'Laporan dengan ID 123 sudah ada.');
});

test('Error Mapping - Maps Postgres 23505 generic constraint to CONFLICT', () => {
  const mockPgError = new Error('duplicate key value violates unique constraint "some_other_key"');
  mockPgError.code = '23505';
  mockPgError.constraint = 'some_other_key';

  const appError = translatePostgresError(mockPgError, 'Report', '123');

  assert.strictEqual(appError.code, 'CONFLICT');
  assert.strictEqual(appError.status, 409);
});

test('Error Mapping - Maps Postgres 23503 to FOREIGN_KEY_CONFLICT', () => {
  const appError = translatePostgresError(
    Object.assign(new Error('raw foreign key details'), { code: '23503' }),
    'Report',
    '123'
  );

  assert.strictEqual(appError.code, 'FOREIGN_KEY_CONFLICT');
  assert.strictEqual(appError.status, 409);
  assert.strictEqual(appError.message.includes('raw foreign key details'), false);
});

test('Error Mapping - Maps Postgres 57014 to DATABASE_TIMEOUT', () => {
  const appError = translatePostgresError(
    Object.assign(new Error('canceling statement due to statement timeout'), { code: '57014' }),
    'Report',
    '123'
  );

  assert.strictEqual(appError.code, 'DATABASE_TIMEOUT');
  assert.strictEqual(appError.status, 503);
  assert.strictEqual(appError.message.includes('canceling statement'), false);

  const domainError = translatePostgresError(
    Object.assign(
      new Error(
        'Report QC-1 with status APPROVED requires an explicit final conclusion'
      ),
      { code: '23514' }
    ),
    'Report',
    'QC-1'
  );
  assert.strictEqual(
    domainError.message,
    'Kesimpulan akhir wajib diisi sebelum laporan dapat diselesaikan.'
  );
});

test('Error Mapping - Sanitizes unknown database errors as INTERNAL_ERROR', () => {
  const appError = translatePostgresError(
    Object.assign(new Error('secret database detail'), { code: 'XX999' }),
    'Report',
    '123'
  );

  assert.strictEqual(appError.code, 'INTERNAL_ERROR');
  assert.strictEqual(appError.status, 500);
  assert.strictEqual(appError.message, 'Terjadi kesalahan internal.');
});

test('Error Handler - Emits canonical top-level fields without public details', () => {
  const appErr = new AppError({
    status: 400,
    code: 'VALIDATION_ERROR',
    message: 'Invalid input',
    details: [{ path: 'title', message: 'Required' }]
  });

  let capturedStatus = 0;
  let capturedBody = null;
  const res = {
    status: code => { capturedStatus = code; return res; },
    json: body => { capturedBody = body; }
  };

  errorHandler(appErr, {}, res, () => {});

  assert.strictEqual(capturedStatus, 400);
  assert.deepEqual(capturedBody, {
    code: 'VALIDATION_ERROR',
    message: 'Invalid input',
    status: 400,
    error: { code: 'VALIDATION_ERROR', message: 'Invalid input' }
  });
  assert.strictEqual(JSON.stringify(capturedBody).includes('title'), false);
});

test('Error Handler - Sanitizes internal errors and never leaks stack', () => {
  const internalErr = new Error('Database connection failed! db_host=secret');
  internalErr.stack = 'Error: Database connection failed... at dbConnect (secret.js:1:1)';

  let capturedStatus = 0;
  let capturedBody = null;
  const res = {
    status: code => { capturedStatus = code; return res; },
    json: body => { capturedBody = body; }
  };

  errorHandler(internalErr, {}, res, () => {});

  assert.strictEqual(capturedStatus, 500);
  assert.deepEqual(capturedBody, {
    code: 'INTERNAL_ERROR',
    message: 'Terjadi kesalahan internal.',
    status: 500,
    error: { code: 'INTERNAL_ERROR', message: 'Terjadi kesalahan internal.' }
  });

  const jsonStr = JSON.stringify(capturedBody);
  assert.strictEqual(jsonStr.includes('db_host'), false);
  assert.strictEqual(jsonStr.includes('stack'), false);
  assert.strictEqual(jsonStr.includes('Database connection failed'), false);
});
