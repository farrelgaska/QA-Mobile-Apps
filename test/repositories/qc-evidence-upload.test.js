const test = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');
const { createUploadRouter, MAX_FILE_SIZE } = require('../../src/routes/upload.routes');
const errorHandler = require('../../src/middleware/error-handler');
const {
  createQCEvidenceStorage,
  createQCEvidenceStorageProvider
} = require('../../src/storage/qc-evidence-storage');

const JPEG_BYTES = Buffer.from([
  0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46,
  0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01
]);
const PNG_BYTES = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nQAAAABJRU5ErkJggg==',
  'base64'
);

const jpegWithSize = size => {
  const bytes = Buffer.alloc(size);
  JPEG_BYTES.copy(bytes);
  return bytes;
};

const createStorageMock = () => ({
  uploads: [],
  signedUrlRequests: [],
  async upload(objectPath, file) {
    this.uploads.push({ objectPath, file });
  },
  async createSignedUrls(paths) {
    this.signedUrlRequests.push(paths);
    return {
      signedUrls: paths.map(path => ({
        object_path: path,
        signed_url: `https://storage.example.test/${encodeURIComponent(path)}`,
        expires_in: 3600
      })),
      failedPaths: []
    };
  }
});

const createSupabaseStorage = response => createQCEvidenceStorage({
  storage: {
    from(bucket) {
      assert.equal(bucket, 'qc-evidence');
      return {
        async createSignedUrls(paths, expiresIn) {
          assert.equal(expiresIn, 3600);
          return typeof response === 'function' ? response(paths) : response;
        }
      };
    }
  }
});

const withServer = async (storage, callback) => {
  const app = express();
  app.use('/uploads', createUploadRouter({ getStorage: () => storage }));
  app.use(errorHandler);
  const server = app.listen(0);
  await new Promise(resolve => server.once('listening', resolve));
  try {
    await callback(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
};

const uploadForm = ({
  bytes = JPEG_BYTES,
  mimeType = 'image/jpeg',
  reportId = 'QC-REP-001',
  category = 'general',
  itemId
} = {}) => {
  const form = new FormData();
  form.append('file', new Blob([bytes], { type: mimeType }), 'client-filename.jpg');
  form.append('report_id', reportId);
  form.append('category', category);
  if (itemId !== undefined) form.append('item_id', itemId);
  return form;
};

test('uploads QC evidence successfully', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm()
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.match(body.object_path, /^reports\/QC-REP-001\/general\/[0-9a-f-]{36}\.jpg$/);
    assert.equal(body.mime_type, 'image/jpeg');
    assert.equal(body.size, JPEG_BYTES.length);
    assert.equal(storage.uploads.length, 1);
    assert.equal(storage.uploads[0].objectPath, body.object_path);
  });
});

test('accepts a QC evidence image smaller than 2 MB', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const bytes = jpegWithSize(MAX_FILE_SIZE - 1);
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ bytes })
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.size, MAX_FILE_SIZE - 1);
    assert.equal(storage.uploads.length, 1);
  });
});

test('accepts a QC evidence image exactly 2 MB and preserves its canonical path', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({
        bytes: jpegWithSize(MAX_FILE_SIZE),
        category: 'checklist',
        itemId: 'item-2mb'
      })
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.size, MAX_FILE_SIZE);
    assert.match(
      body.object_path,
      /^reports\/QC-REP-001\/checklist\/item-2mb\/[0-9a-f-]{36}\.jpg$/
    );
    assert.equal(storage.uploads.length, 1);
    assert.equal(storage.uploads[0].objectPath, body.object_path);
  });
});

test('rejects an upload with no file', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const form = new FormData();
    form.append('report_id', 'QC-REP-001');
    form.append('category', 'general');
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, { method: 'POST', body: form });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'file is required' });
    assert.equal(storage.uploads.length, 0);
  });
});

test('rejects a zero-byte file', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ bytes: Buffer.alloc(0) })
    });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'file must not be empty' });
    assert.equal(storage.uploads.length, 0);
  });
});

test('rejects an invalid image MIME type', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ mimeType: 'application/pdf' })
    });

    assert.equal(response.status, 415);
    assert.deepEqual(await response.json(), { error: 'file must be JPEG, PNG, WebP, or HEIC' });
    assert.equal(storage.uploads.length, 0);
  });
});

test('rejects a spoofed image MIME type', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ bytes: PNG_BYTES, mimeType: 'image/jpeg' })
    });

    assert.equal(response.status, 415);
    assert.deepEqual(await response.json(), { error: 'file MIME type does not match its content' });
    assert.equal(storage.uploads.length, 0);
  });
});

test('accepts a valid real PNG signature', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ bytes: PNG_BYTES, mimeType: 'image/png' })
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.mime_type, 'image/png');
    assert.equal(body.size, PNG_BYTES.length);
    assert.match(body.object_path, /\.png$/);
  });
});

test('rejects a QC evidence image larger than 2 MB before Storage upload', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ bytes: jpegWithSize(MAX_FILE_SIZE + 1) })
    });

    assert.equal(response.status, 413);
    assert.notEqual(response.status, 500);
    assert.deepEqual(await response.json(), { error: 'Ukuran gambar maksimal 2 MB.' });
    assert.equal(storage.uploads.length, 0);
  });
});

test('requires item_id for checklist evidence', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ category: 'checklist' })
    });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'item_id is required' });
    assert.equal(storage.uploads.length, 0);
  });
});

test('generates a safe checklist object path from valid identifiers', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({
        reportId: 'QC-Report-002',
        category: 'checklist',
        itemId: 'item-safe-01'
      })
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.match(
      body.object_path,
      /^reports\/QC-Report-002\/checklist\/item-safe-01\/[0-9a-f-]{36}\.jpg$/
    );
    assert.equal(body.object_path.includes('client-filename'), false);
  });
});

test('rejects an unsafe report_id instead of transforming it', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ reportId: '../../QC Report 002' })
    });

    assert.equal(response.status, 400);
    assert.match((await response.json()).error, /^report_id must be at most 128 characters/);
    assert.equal(storage.uploads.length, 0);
  });
});

test('rejects an unsafe item_id instead of transforming it', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm({ category: 'checklist', itemId: '../item/unsafe 01' })
    });

    assert.equal(response.status, 400);
    assert.match((await response.json()).error, /^item_id must be at most 128 characters/);
    assert.equal(storage.uploads.length, 0);
  });
});

test('returns an upstream error when Storage upload fails', async () => {
  const storage = createStorageMock();
  storage.upload = async () => {
    const error = new Error('QC evidence storage upload failed');
    error.statusCode = 502;
    throw error;
  };
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence`, {
      method: 'POST',
      body: uploadForm()
    });

    assert.equal(response.status, 502);
    assert.deepEqual(await response.json(), { error: 'QC evidence storage upload failed' });
  });
});

test('creates signed URLs for valid QC evidence paths', async () => {
  const storage = createStorageMock();
  const path = 'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174000.jpg';
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence/signed-urls`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ paths: [path] })
    });
    const body = await response.json();

    assert.equal(response.status, 200);
    assert.equal(body.expires_in, 3600);
    assert.deepEqual(body.failed_paths, []);
    assert.deepEqual(storage.signedUrlRequests, [[path]]);
    assert.deepEqual(body.signed_urls, [{
      object_path: path,
      signed_url: `https://storage.example.test/${encodeURIComponent(path)}`,
      expires_in: 3600
    }]);
  });
});

test('Supabase adapter returns every signed URL when all paths succeed', async () => {
  const paths = [
    'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174000.jpg',
    'reports/QC-REP-001/checklist/item-1/123e4567-e89b-42d3-a456-426614174001.png'
  ];
  const storage = createSupabaseStorage({
    data: paths.map(path => ({ path, signedUrl: `https://storage.example.test/${path}` })),
    error: null
  });

  assert.deepEqual(await storage.createSignedUrls(paths), {
    signedUrls: paths.map(path => ({
      object_path: path,
      signed_url: `https://storage.example.test/${path}`,
      expires_in: 3600
    })),
    failedPaths: []
  });
});

test('returns valid signed URLs and reports only missing paths in a mixed batch', async () => {
  const validPath = 'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174000.jpg';
  const missingPath = 'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174001.jpg';
  const signedUrl = `https://storage.example.test/${validPath}`;
  const storage = createSupabaseStorage({
    data: [
      { path: validPath, signedUrl },
      { path: missingPath, signedUrl: null, error: 'Object not found' }
    ],
    error: null
  });

  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence/signed-urls`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ paths: [validPath, missingPath] })
    });

    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      signed_urls: [{ object_path: validPath, signed_url: signedUrl, expires_in: 3600 }],
      failed_paths: [missingPath],
      expires_in: 3600
    });
  });
});

test('returns an empty signed URL list when every object is missing', async () => {
  const paths = [
    'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174000.jpg',
    'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174001.jpg'
  ];
  const storage = createSupabaseStorage({
    data: paths.map(path => ({ path, signedUrl: null, error: 'Object not found' })),
    error: null
  });

  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence/signed-urls`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ paths })
    });

    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {
      signed_urls: [],
      failed_paths: paths,
      expires_in: 3600
    });
  });
});

test('Supabase adapter still throws on a top-level signed URL failure', async () => {
  const path = 'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174000.jpg';
  const storage = createSupabaseStorage({ data: null, error: { message: 'Storage unavailable' } });

  await assert.rejects(
    storage.createSignedUrls([path]),
    error => error.statusCode === 502 && error.message === 'QC evidence signed URL creation failed'
  );
});

test('Supabase adapter still throws on a malformed signed URL response', async () => {
  const path = 'reports/QC-REP-001/general/123e4567-e89b-42d3-a456-426614174000.jpg';
  const storage = createSupabaseStorage({ data: null, error: null });

  await assert.rejects(
    storage.createSignedUrls([path]),
    error => error.statusCode === 502 && error.message === 'QC evidence signed URL creation failed'
  );
});

test('rejects an invalid signed URL path', async () => {
  const storage = createStorageMock();
  await withServer(storage, async baseUrl => {
    const response = await fetch(`${baseUrl}/uploads/qc-evidence/signed-urls`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ paths: ['../another-bucket/private.jpg'] })
    });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'paths contains an invalid QC evidence object path' });
    assert.equal(storage.signedUrlRequests.length, 0);
  });
});

test('Supabase adapter refuses to initialize without its credentials', () => {
  const getStorage = createQCEvidenceStorageProvider({
    config: { STORAGE_PROVIDER: 'supabase' },
    clientFactory: () => assert.fail('client factory must not be called')
  });

  assert.throws(getStorage, /Supabase Storage is not configured/);
});

test('non-Supabase providers cannot initialize the Supabase adapter', () => {
  for (const storageProvider of ['s3', 'gcs']) {
    const getStorage = createQCEvidenceStorageProvider({
      config: {
        STORAGE_PROVIDER: storageProvider,
        SUPABASE_URL: 'https://example.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: 'placeholder'
      },
      clientFactory: () => assert.fail('client factory must not be called')
    });

    assert.throws(getStorage, /requires STORAGE_PROVIDER=supabase/);
  }
});
