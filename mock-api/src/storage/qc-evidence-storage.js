const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');
const environment = require('../config/env');

const QC_EVIDENCE_BUCKET = 'qc-evidence';
const SIGNED_URL_EXPIRY_SECONDS = 3600;

const storageFailure = message => {
  const error = new Error(message);
  error.statusCode = 502;
  return error;
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

const createQCEvidenceStorageProvider = ({
  config = environment,
  clientFactory = createClient
} = {}) => {
  let sharedStorage;

  return () => {
    if (sharedStorage) return sharedStorage;
    if (config.STORAGE_PROVIDER !== 'supabase') {
      if (config.NODE_ENV === 'production') {
        const error = new Error('QC evidence upload requires STORAGE_PROVIDER=supabase in production');
        error.statusCode = 503;
        throw error;
      }
      
      const localBasePath = path.join(__dirname, '../../.local-storage/qc-evidence');
      
      let fallbackClient = null;
      if (config.SUPABASE_URL && config.SUPABASE_SERVICE_ROLE_KEY) {
        fallbackClient = clientFactory(config.SUPABASE_URL, config.SUPABASE_SERVICE_ROLE_KEY, {
          auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false }
        });
      }
      
      sharedStorage = {
        async upload(objectPath, file) {
          const absolutePath = path.join(localBasePath, objectPath);
          await fs.promises.mkdir(path.dirname(absolutePath), { recursive: true });
          await fs.promises.writeFile(absolutePath, file.buffer);
        },
        async remove(paths) {
          if (!Array.isArray(paths) || paths.length === 0) return;
          for (const p of paths) {
            try {
              await fs.promises.unlink(path.join(localBasePath, p));
            } catch (err) {
              if (err.code !== 'ENOENT') throw err;
            }
          }
        },
        async createSignedUrls(paths) {
          const result = { signedUrls: [], failedPaths: [] };
          const remotePaths = [];

          for (const p of paths) {
            try {
              await fs.promises.stat(path.join(localBasePath, p));
              result.signedUrls.push({
                object_path: p,
                signed_url: `${config.API_BASE_URL || 'http://localhost:3002'}/mock-storage/${p}`,
                expires_in: 3600
              });
            } catch (err) {
              remotePaths.push(p);
            }
          }

          if (remotePaths.length > 0) {
            if (fallbackClient) {
              const { data, error } = await fallbackClient.storage
                .from(QC_EVIDENCE_BUCKET)
                .createSignedUrls(remotePaths, SIGNED_URL_EXPIRY_SECONDS);

              if (error || !Array.isArray(data)) {
                result.failedPaths.push(...remotePaths);
              } else {
                data.forEach((entry, index) => {
                  const objectPath = entry?.path || remotePaths[index];
                  if (entry?.error || typeof entry?.signedUrl !== 'string' || entry.signedUrl === '') {
                    result.failedPaths.push(objectPath);
                  } else {
                    result.signedUrls.push({
                      object_path: objectPath,
                      signed_url: entry.signedUrl,
                      expires_in: SIGNED_URL_EXPIRY_SECONDS
                    });
                  }
                });
              }
            } else {
              result.failedPaths.push(...remotePaths);
            }
          }

          return result;
        }
      };
      return sharedStorage;
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
  createQCEvidenceStorage,
  createQCEvidenceStorageProvider,
  getQCEvidenceStorage
};
