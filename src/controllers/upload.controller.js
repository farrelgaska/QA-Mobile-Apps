const { randomUUID } = require('crypto');
const { SIGNED_URL_EXPIRY_SECONDS } = require('../storage/qc-evidence-storage');
const environment = require('../config/env');
const logger = require('../utils/logger');

const MAX_SIGNED_URL_PATHS = 50;
const MAX_QC_EVIDENCE_SIZE_BYTES = 2 * 1024 * 1024;
const QC_EVIDENCE_TOO_LARGE_MESSAGE = 'Ukuran gambar maksimal 2 MB.';
const MIME_EXTENSIONS = Object.freeze({
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic'
});
const SAFE_SEGMENT_PATTERN = /^[A-Za-z0-9_-]+$/;
const UUID_PATTERN = '[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}';
const SIGNABLE_PATH_PATTERN = new RegExp(
  `^reports/[A-Za-z0-9_-]{1,128}/(?:general/${UUID_PATTERN}|checklist/[A-Za-z0-9_-]{1,128}/${UUID_PATTERN})\\.(?:jpg|png|webp|heic)$`
);

const AppError = require('../utils/AppError');

const requestError = (message, statusCode = 400) => {
  return new AppError({
    status: statusCode,
    code: statusCode === 413 ? 'PAYLOAD_TOO_LARGE' : statusCode === 415 ? 'UNSUPPORTED_MEDIA_TYPE' : 'BAD_REQUEST',
    message
  });
};

const validateIdentifier = (value, fieldName) => {
  const label = fieldName === 'report_id' ? 'ID laporan' : 'ID parameter';
  if (typeof value !== 'string' || value.trim() === '') {
    throw requestError(`${label} wajib diisi.`);
  }
  const identifier = value.trim();
  if (identifier.length > 128 || !SAFE_SEGMENT_PATTERN.test(identifier)) {
    throw requestError(
      `${label} maksimal 128 karakter dan hanya boleh berisi huruf, angka, garis bawah, atau tanda hubung.`
    );
  }
  return identifier;
};

const detectImageType = async buffer => {
  try {
    const { fileTypeFromBuffer } = await import('file-type');
    return await fileTypeFromBuffer(buffer);
  } catch (_) {
    return undefined;
  }
};

const createUploadController = ({ getStorage }) => ({
  uploadEvidence: async (req, res, next) => {
    try {
      if (!req.file) throw requestError('Foto wajib disertakan.');
      if (req.file.size === 0) throw requestError('Foto tidak boleh kosong.');
      if (req.file.size > MAX_QC_EVIDENCE_SIZE_BYTES) {
        throw requestError(QC_EVIDENCE_TOO_LARGE_MESSAGE, 413);
      }

      const detectedType = await detectImageType(req.file.buffer);
      if (!detectedType || !Object.hasOwn(MIME_EXTENSIONS, detectedType.mime)) {
        throw requestError('Format foto harus JPEG, PNG, WebP, atau HEIC.', 415);
      }
      if (detectedType.mime !== req.file.mimetype) {
        throw requestError('Jenis berkas foto tidak sesuai dengan isinya.', 415);
      }

      const reportId = validateIdentifier(req.body.report_id, 'report_id');
      const category = req.body.category;
      if (!['general', 'checklist'].includes(category)) {
        throw requestError('Kategori dokumentasi tidak valid.');
      }

      let objectPath;
      const filename = `${randomUUID()}.${MIME_EXTENSIONS[detectedType.mime]}`;
      if (category === 'general') {
        objectPath = `reports/${reportId}/general/${filename}`;
      } else {
        const itemId = validateIdentifier(req.body.item_id, 'item_id');
        objectPath = `reports/${reportId}/checklist/${itemId}/${filename}`;
      }

      const storageProvider = environment.STORAGE_PROVIDER ||
        (environment.DATA_PROVIDER === 'json' ? 'local' : 'unconfigured');
      req.observability = {
        operation: 'evidence_upload',
        report_id: reportId,
        storage_provider: storageProvider
      };
      await getStorage().upload(objectPath, req.file);
      logger.info('evidence_upload_succeeded', {
        request_id: req.requestId,
        report_id: reportId,
        object_path: objectPath,
        storage_provider: storageProvider,
        mime_type: detectedType.mime,
        size_bytes: req.file.size
      });
      res.status(201).json({
        object_path: objectPath,
        mime_type: detectedType.mime,
        size: req.file.size
      });
    } catch (error) {
      next(error);
    }
  },

  createSignedUrls: async (req, res, next) => {
    try {
      const paths = req.body?.paths;
      if (!Array.isArray(paths) || paths.length === 0) {
        throw requestError('Daftar dokumentasi wajib diisi.');
      }
      if (paths.length > MAX_SIGNED_URL_PATHS) {
        throw requestError(`Daftar dokumentasi maksimal berisi ${MAX_SIGNED_URL_PATHS} entri.`);
      }
      if (paths.some(path => typeof path !== 'string' || !SIGNABLE_PATH_PATTERN.test(path))) {
        throw requestError('Daftar dokumentasi memuat path yang tidak valid.');
      }

      const baseUrl = req.protocol + '://' + req.get('host');
      const { signedUrls, failedPaths } = await getStorage().createSignedUrls(paths, { baseUrl });
      if (failedPaths.length > 0) {
        logger.warn('evidence_resolution_partial', {
          request_id: req.requestId,
          requested_count: paths.length,
          failed_count: failedPaths.length,
          storage_provider: environment.STORAGE_PROVIDER ||
            (environment.DATA_PROVIDER === 'json' ? 'local' : 'unconfigured')
        });
      }
      res.json({
        signed_urls: signedUrls,
        failed_paths: failedPaths,
        expires_in: SIGNED_URL_EXPIRY_SECONDS
      });
    } catch (error) {
      next(error);
    }
  }
});

module.exports = {
  MAX_SIGNED_URL_PATHS,
  MAX_QC_EVIDENCE_SIZE_BYTES,
  QC_EVIDENCE_TOO_LARGE_MESSAGE,
  MIME_EXTENSIONS,
  SIGNABLE_PATH_PATTERN,
  createUploadController,
  validateIdentifier
};
