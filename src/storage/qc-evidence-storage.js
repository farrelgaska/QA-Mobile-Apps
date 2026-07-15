const { createClient } = require('@supabase/supabase-js');
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

  async createSignedUrls(paths) {
    const { data, error } = await supabaseClient.storage
      .from(QC_EVIDENCE_BUCKET)
      .createSignedUrls(paths, SIGNED_URL_EXPIRY_SECONDS);

    if (error || !Array.isArray(data) || data.some(entry => entry.error || !entry.signedUrl)) {
      throw storageFailure('QC evidence signed URL creation failed');
    }

    return data.map(entry => ({
      object_path: entry.path,
      signed_url: entry.signedUrl,
      expires_in: SIGNED_URL_EXPIRY_SECONDS
    }));
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
      const error = new Error('QC evidence Storage requires STORAGE_PROVIDER=supabase');
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
  createQCEvidenceStorage,
  createQCEvidenceStorageProvider,
  getQCEvidenceStorage
};
