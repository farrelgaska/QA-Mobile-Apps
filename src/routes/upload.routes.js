const express = require('express');
const multer = require('multer');
const { createUploadController, MIME_EXTENSIONS } = require('../controllers/upload.controller');
const { getQCEvidenceStorage } = require('../storage/qc-evidence-storage');

const MAX_FILE_SIZE = 10 * 1024 * 1024;

const multipartUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1,
    fields: 3
  },
  fileFilter: (req, file, callback) => {
    if (!Object.hasOwn(MIME_EXTENSIONS, file.mimetype)) {
      const error = new Error('file must be JPEG, PNG, WebP, or HEIC');
      error.statusCode = 415;
      return callback(error);
    }
    callback(null, true);
  }
});

const createUploadRouter = ({ getStorage = getQCEvidenceStorage } = {}) => {
  const router = express.Router();
  const controller = createUploadController({ getStorage });

  router.post('/qc-evidence', multipartUpload.single('file'), controller.uploadEvidence);
  router.post('/qc-evidence/signed-urls', express.json(), controller.createSignedUrls);

  router.use((error, req, res, next) => {
    if (error instanceof multer.MulterError) {
      if (error.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({ error: 'file must not exceed 10 MB' });
      }
      return res.status(400).json({ error: 'Invalid multipart upload' });
    }
    next(error);
  });

  return router;
};

const router = createUploadRouter();

module.exports = router;
module.exports.createUploadRouter = createUploadRouter;
module.exports.MAX_FILE_SIZE = MAX_FILE_SIZE;
