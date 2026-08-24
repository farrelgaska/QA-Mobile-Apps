const { createClient } = require('@supabase/supabase-js');
const fs = require('fs/promises');
const path = require('path');
const environment = require('../config/env');
const {
  CANONICAL_QC_EVIDENCE_PATH_PATTERN
} = require('../contracts/report.contract');

const QC_EVIDENCE_BUCKET = 'qc-evidence';
const SIGNED_URL_EXPIRY_SECONDS = 3600;
const LOCAL_QC_EVIDENCE_ROOT = path.join(__dirname, '../../.local-storage/qc-evidence');

const storageFailure = message => {
  const error = new Error(message);
  error.statusCode = 502;
  return error;
};

const collectReportPhotoPaths = report => {
  const paths = [
    ...(report.general_photos ?? []),
    ...(report.checklist_items ?? []).flatMap(item => item.item_photos ?? []),
    ...(report.samples ?? []).flatMap(sample => [
      ...(sample.photo_paths ?? []),
      ...(sample.checklist_answers ?? []).flatMap(answer => answer.photo_paths ?? [])
    ])
  ];
  return [...new Set(paths)].filter(value =>
    typeof value === 'string' && CANONICAL_QC_EVIDENCE_PATH_PATTERN.test(value)
  );
};

const localObjectPath = objectPath => {
  if (!CANONICAL_QC_EVIDENCE_PATH_PATTERN.test(objectPath)) {
    throw storageFailure('Invalid QC evidence object path');
  }
  return path.join(LOCAL_QC_EVIDENCE_ROOT, objectPath);
};

const createQCEvidenceStorage = supabaseClient => ({
  async upload(objectPath, file) {
    const { error } = await supabaseClient.storage
      .from(QC_EVIDENCE_BUCKET)
      .upload(objectPath, file.buffer, {
        contentType: file.mimetype,
        upsert: false
      });

    if (error) throw storageFailure('QC evidence storage upload failed');
  },

  async remove(paths) {
    if (!Array.isArray(paths) || paths.length === 0) return;
    const { error } = await supabaseClient.storage
      .from(QC_EVIDENCE_BUCKET)
      .remove(paths);
    if (error) throw storageFailure('QC evidence storage remove failed');
  },

  async createSignedUrls(paths) {
    const response = await supabaseClient.storage
      .from(QC_EVIDENCE_BUCKET)
      .createSignedUrls(paths, SIGNED_URL_EXPIRY_SECONDS);

    if (!response || response.error || !Array.isArray(response.data)) {
      throw storageFailure('QC evidence signed URL creation failed');
    }
    const { data } = response;

    return paths.reduce(
      (result, path, index) => {
        const entry = data[index];
        const objectPath = entry?.path || path;

        if (entry?.error || typeof entry?.signedUrl !== 'string' || entry.signedUrl === '') {
          result.failedPaths.push(objectPath);
        } else {
          result.signedUrls.push({
            object_path: objectPath,
            signed_url: entry.signedUrl,
            expires_in: SIGNED_URL_EXPIRY_SECONDS
          });
        }

        return result;
      },
      { signedUrls: [], failedPaths: [] }
    );
  }
});

const createLocalEvidenceStorage = (config) => ({
  async upload(objectPath, file) {
    const fullPath = localObjectPath(objectPath);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, file.buffer);
  },

  async remove(paths) {
    if (!Array.isArray(paths) || paths.length === 0) return;
    for (const p of paths) {
      try {
        await fs.unlink(localObjectPath(p));
      } catch (err) {
        if (err.code !== 'ENOENT') throw storageFailure('Local storage remove failed');
      }
    }
  },

  async createSignedUrls(paths, { baseUrl } = {}) {
    const defaultBaseUrl = `http://127.0.0.1:${config.PORT || 3002}`;
    const urlPrefix = baseUrl || defaultBaseUrl;

    const result = { signedUrls: [], failedPaths: [] };
    for (const p of paths) {
      const fullPath = localObjectPath(p);
      try {
        await fs.access(fullPath);
        result.signedUrls.push({
          object_path: p,
          signed_url: `${urlPrefix}/mock-storage/${p}`,
          expires_in: SIGNED_URL_EXPIRY_SECONDS
        });
      } catch (error) {
        if (error.code === 'ENOENT') result.failedPaths.push(p);
        else throw storageFailure('Local storage signed URL creation failed');
      }
    }
    return result;
  }
});

const createQCEvidenceStorageProvider = ({
  config = environment,
  clientFactory = createClient
} = {}) => {
  let sharedStorage;

  return () => {
    if (sharedStorage) return sharedStorage;

    if (config.STORAGE_PROVIDER === 'local' || (!config.STORAGE_PROVIDER && config.DATA_PROVIDER === 'json')) {
      sharedStorage = createLocalEvidenceStorage(config);
      return sharedStorage;
    }

    if (config.STORAGE_PROVIDER !== 'supabase') {
      const error = new Error('QC evidence Storage requires STORAGE_PROVIDER=supabase or local');
      error.statusCode = 503;
      throw error;
    }
    if (!config.SUPABASE_URL || !config.SUPABASE_SERVICE_ROLE_KEY) {
      const error = new Error('Supabase Storage is not configured');
      error.statusCode = 503;
      throw error;
    }

    const client = clientFactory(
      config.SUPABASE_URL,
      config.SUPABASE_SERVICE_ROLE_KEY,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUrl: false
        }
      }
    );
    sharedStorage = createQCEvidenceStorage(client);
    return sharedStorage;
  };
};

const getQCEvidenceStorage = createQCEvidenceStorageProvider();

module.exports = {
  QC_EVIDENCE_BUCKET,
  SIGNED_URL_EXPIRY_SECONDS,
  LOCAL_QC_EVIDENCE_ROOT,
  collectReportPhotoPaths,
  createQCEvidenceStorage,
  createQCEvidenceStorageProvider,
  getQCEvidenceStorage
};
