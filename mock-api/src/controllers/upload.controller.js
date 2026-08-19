const { randomUUID } = require('crypto');
const { SIGNED_URL_EXPIRY_SECONDS } = require('../storage/qc-evidence-storage');

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

const requestError = (message, statusCode = 400) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
};

const validateIdentifier = (value, fieldName) => {
  if (typeof value !== 'string' || value.trim() === '') {
    throw requestError(`${fieldName} is required`);
  }
  const identifier = value.trim();
  if (identifier.length > 128 || !SAFE_SEGMENT_PATTERN.test(identifier)) {
    throw requestError(
      `${fieldName} must be at most 128 characters and contain only letters, numbers, underscores, or hyphens`
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
      if (!req.file) throw requestError('file is required');
      if (req.file.size === 0) throw requestError('file must not be empty');
      if (req.file.size > MAX_QC_EVIDENCE_SIZE_BYTES) {
        throw requestError(QC_EVIDENCE_TOO_LARGE_MESSAGE, 413);
      }

      const detectedType = await detectImageType(req.file.buffer);
      if (!detectedType || !Object.hasOwn(MIME_EXTENSIONS, detectedType.mime)) {
        throw requestError('file content must be JPEG, PNG, WebP, or HEIC', 415);
      }
      if (detectedType.mime !== req.file.mimetype) {
        throw requestError('file MIME type does not match its content', 415);
      }

      const reportId = validateIdentifier(req.body.report_id, 'report_id');
      const category = req.body.category;
      if (!['general', 'checklist'].includes(category)) {
        throw requestError('category must be either general or checklist');
      }

      let objectPath;
      const filename = `${randomUUID()}.${MIME_EXTENSIONS[detectedType.mime]}`;
      if (category === 'general') {
        objectPath = `reports/${reportId}/general/${filename}`;
      } else {
        const itemId = validateIdentifier(req.body.item_id, 'item_id');
        objectPath = `reports/${reportId}/checklist/${itemId}/${filename}`;
      }

      await getStorage().upload(objectPath, req.file);
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
        throw requestError('paths must be a non-empty array');
      }
      if (paths.length > MAX_SIGNED_URL_PATHS) {
        throw requestError(`paths cannot contain more than ${MAX_SIGNED_URL_PATHS} entries`);
      }
      if (paths.some(path => typeof path !== 'string' || !SIGNABLE_PATH_PATTERN.test(path))) {
        throw requestError('paths contains an invalid QC evidence object path');
      }

      const { signedUrls, failedPaths } = await getStorage().createSignedUrls(paths);
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
