const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  JsonReportRepository
} = require('../../src/repositories/json-report.repository');
const {
  PostgresReportRepository
} = require('../../src/repositories/postgres-report.repository');
const {
  QC_EVIDENCE_CAPTURE_METADATA_FIELD,
  normalizeQCEvidenceCaptureMetadata
} = require('../../src/contracts/qc-evidence-capture-metadata');

const PHOTO_PATH =
  'reports/QC-EVIDENCE-1/checklist/dimension/123e4567-e89b-42d3-a456-426614174000.jpg';
const SECOND_PHOTO_PATH =
  'reports/QC-EVIDENCE-1/general/123e4567-e89b-42d3-a456-426614174001.png';
const RECEIVED_AT = '2026-07-29T04:00:00.000Z';
const LATER_RECEIVED_AT = '2026-07-29T05:00:00.000Z';

const metadataEntry = (overrides = {}) => ({
  capturedAt: '2026-07-29T10:30:00.000+07:00',
  latitude: -6.2088,
  longitude: 106.8456,
  accuracyMeters: 3.25,
  locationLabel: null,
  ...overrides
});

const report = (generalInfo = {}) => ({
  id: 'QC-EVIDENCE-1',
  type: 'MATERIAL',
  title: 'Evidence metadata',
  status: 'DRAFT',
  staff: { name: 'Warehouse Staff', nik: 'WH-1' },
  location: {},
  general_info: generalInfo,
  checklist_items: [],
  sample_count: 1,
  samples: []
});

const repositoryFixture = (t, now = () => new Date(RECEIVED_AT)) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mock-api-evidence-metadata-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const filePath = path.join(directory, 'reports.json');
  fs.writeFileSync(filePath, '[]');
  return {
    filePath,
    repository: new JsonReportRepository(filePath, { now })
  };
};

class RecordingPool {
  constructor(root = null) {
    this.root = root;
    this.queries = [];
    this.client = {
      query: async (text, parameters = []) => {
        this.queries.push({ text, parameters });
        if (text.includes('from public.qc_reports where id = $1')) {
          return { rows: this.root ? [this.root] : [], rowCount: this.root ? 1 : 0 };
        }
        if (/update public\.qc_reports set/i.test(text)) {
          this.root = {
            ...this.root,
            id: parameters[0],
            type: parameters[1],
            template_id: parameters[2],
            form_code: parameters[3],
            title: parameters[4],
            status: parameters[5],
            staff_name: parameters[6],
            staff_nik: parameters[7],
            site_id: parameters[8],
            site_name: parameters[9],
            area: parameters[10],
            detail_location: parameters[11],
            general_info: parameters[12],
            staff_note: parameters[13],
            submitted_at: parameters[14],
            revision_number: parameters[15],
            migration_metadata: parameters[16],
            sample_count: parameters[17],
            review_requested: parameters[18],
            review_requested_at: parameters[19],
            review_requested_by_role: parameters[20],
            review_failed_sample_count: parameters[21],
            review_failed_sample_ids: parameters[22],
            review_failed_sample_numbers: parameters[23]
          };
          return { rows: [], rowCount: 1 };
        }
        return { rows: [], rowCount: 0 };
      },
      release: () => {}
    };
  }

  async connect() {
    return this.client;
  }
}

test('valid capture metadata is normalized, persisted, and returned by JSON reads', t => {
  const { filePath, repository } = repositoryFixture(t);
  const generalInfo = {
    poNumber: 'PO-2026-017',
    [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
      [PHOTO_PATH]: metadataEntry({
        locationLabel: '  Gudang Utama  ',
        serverReceivedAt: '2000-01-01T00:00:00.000Z'
      })
    }
  };

  repository.create(report(generalInfo));
  const restored = new JsonReportRepository(filePath).findById('QC-EVIDENCE-1');
  const restoredEntry =
    restored.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD][PHOTO_PATH];

  assert.deepEqual(restoredEntry, {
    capturedAt: '2026-07-29T10:30:00.000+07:00',
    latitude: -6.2088,
    longitude: 106.8456,
    accuracyMeters: 3.25,
    locationLabel: 'Gudang Utama',
    serverReceivedAt: RECEIVED_AT
  });
  assert.equal(restored.general_info.poNumber, 'PO-2026-017');
});

test('serverReceivedAt is preserved through draft and submit PATCH updates', t => {
  const clockValues = [
    new Date(RECEIVED_AT),
    new Date(LATER_RECEIVED_AT),
    new Date('2026-07-29T06:00:00.000Z')
  ];
  const { repository } = repositoryFixture(t, () => clockValues.shift());
  repository.create(report({
    vendor: 'Vendor A',
    [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
      [PHOTO_PATH]: metadataEntry()
    }
  }));

  const draft = repository.update('QC-EVIDENCE-1', {
    general_info: {
      vendor: 'Vendor A',
      [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
        [PHOTO_PATH]: metadataEntry({ accuracyMeters: 2.5 })
      }
    }
  });
  const submitted = repository.update('QC-EVIDENCE-1', {
    status: 'SUBMITTED',
    general_info: {
      vendor: 'Vendor A',
      [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
        [PHOTO_PATH]: metadataEntry({ latitude: -6.21 })
      }
    }
  });

  assert.equal(
    draft.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD][PHOTO_PATH]
      .serverReceivedAt,
    RECEIVED_AT
  );
  assert.equal(
    submitted.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD][PHOTO_PATH]
      .serverReceivedAt,
    RECEIVED_AT
  );
  assert.equal(
    submitted.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD][PHOTO_PATH].latitude,
    -6.21
  );
  assert.equal(submitted.general_info.vendor, 'Vendor A');
});

test('invalid optional fields are sanitized to null without rejecting valid fields', () => {
  const normalized = normalizeQCEvidenceCaptureMetadata(report({
    [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
      [PHOTO_PATH]: metadataEntry({
        capturedAt: 'not-an-iso-timestamp',
        latitude: -90.01,
        longitude: 180.01,
        accuracyMeters: -0.01,
        locationLabel: 'x'.repeat(257)
      }),
      [SECOND_PHOTO_PATH]: metadataEntry({
        latitude: 90,
        longitude: -180,
        accuracyMeters: 0
      })
    }
  }), { now: () => new Date(RECEIVED_AT) });
  const entries = normalized.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD];

  assert.deepEqual(entries[PHOTO_PATH], {
    capturedAt: null,
    latitude: null,
    longitude: null,
    accuracyMeters: null,
    locationLabel: null,
    serverReceivedAt: RECEIVED_AT
  });
  assert.equal(entries[SECOND_PHOTO_PATH].latitude, 90);
  assert.equal(entries[SECOND_PHOTO_PATH].longitude, -180);
  assert.equal(entries[SECOND_PHOTO_PATH].accuracyMeters, 0);
});

test('malformed containers and entries normalize safely without changing other general_info', () => {
  for (const malformed of [null, [], 'not-an-object', 42]) {
    const normalized = normalizeQCEvidenceCaptureMetadata(report({
      doNumber: 'DO-88',
      [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: malformed
    }), { now: () => new Date(RECEIVED_AT) });

    assert.deepEqual(
      normalized.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD],
      {}
    );
    assert.equal(normalized.general_info.doNumber, 'DO-88');
  }

  const invalidEntries = normalizeQCEvidenceCaptureMetadata(report({
    [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
      '': metadataEntry(),
      'https://example.test/signed-photo.jpg': metadataEntry(),
      [PHOTO_PATH]: 'not-an-entry'
    }
  }), { now: () => new Date(RECEIVED_AT) });
  assert.deepEqual(
    invalidEntries.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD],
    {}
  );
});

test('legacy reports without capture metadata remain unchanged and readable', t => {
  const { filePath, repository } = repositoryFixture(t);
  const legacy = report({ poNumber: 'PO-LEGACY', vendor: 'Vendor Lama' });
  fs.writeFileSync(filePath, JSON.stringify([legacy]));

  const restored = repository.findById('QC-EVIDENCE-1');
  assert.deepEqual(restored.general_info, legacy.general_info);
  assert.equal(
    QC_EVIDENCE_CAPTURE_METADATA_FIELD in restored.general_info,
    false
  );
});

test('PostgreSQL create writes the same normalized general_info JSON shape', async () => {
  const pool = new RecordingPool();
  const input = report({
    materialName: 'Besi Beton',
    [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
      [PHOTO_PATH]: metadataEntry({ locationLabel: '  Area Bongkar  ' })
    }
  });
  await new PostgresReportRepository(pool, {
    now: () => new Date(RECEIVED_AT)
  }).create(input);

  const rootWrite = pool.queries.find(query =>
    query.text.includes('insert into public.qc_reports'));
  assert.deepEqual(rootWrite.parameters[12], {
    materialName: 'Besi Beton',
    [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
      [PHOTO_PATH]: {
        capturedAt: '2026-07-29T10:30:00.000+07:00',
        latitude: -6.2088,
        longitude: 106.8456,
        accuracyMeters: 3.25,
        locationLabel: 'Area Bongkar',
        serverReceivedAt: RECEIVED_AT
      }
    }
  });
});

test('PostgreSQL update preserves an existing valid serverReceivedAt', async () => {
  const pool = new RecordingPool({
    id: 'QC-EVIDENCE-1',
    type: 'MATERIAL',
    template_id: '',
    form_code: '',
    title: 'Evidence metadata',
    status: 'DRAFT',
    staff_name: 'Warehouse Staff',
    staff_nik: 'WH-1',
    site_id: '',
    site_name: '',
    area: '',
    detail_location: '',
    general_info: {
      vendor: 'Vendor A',
      [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
        [PHOTO_PATH]: {
          ...metadataEntry(),
          serverReceivedAt: RECEIVED_AT
        }
      }
    },
    staff_note: '',
    submitted_at: null,
    revision_number: 1,
    migration_metadata: null,
    sample_count: 1,
    review_requested: false,
    review_requested_at: null,
    review_requested_by_role: null,
    review_failed_sample_count: null,
    review_failed_sample_ids: [],
    review_failed_sample_numbers: []
  });
  const repository = new PostgresReportRepository(pool, {
    now: () => new Date(LATER_RECEIVED_AT)
  });

  const updated = await repository.update('QC-EVIDENCE-1', {
    status: 'SUBMITTED',
    general_info: {
      vendor: 'Vendor A',
      [QC_EVIDENCE_CAPTURE_METADATA_FIELD]: {
        [PHOTO_PATH]: metadataEntry({ longitude: 106.9 })
      }
    }
  });

  assert.equal(
    updated.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD][PHOTO_PATH]
      .serverReceivedAt,
    RECEIVED_AT
  );
  assert.equal(
    updated.general_info[QC_EVIDENCE_CAPTURE_METADATA_FIELD][PHOTO_PATH].longitude,
    106.9
  );
  assert.equal(updated.general_info.vendor, 'Vendor A');
});
