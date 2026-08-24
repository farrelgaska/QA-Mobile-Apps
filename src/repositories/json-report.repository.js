const fs = require('fs');
const path = require('path');
const { REPORTS_FILE } = require('../config/env');
const {
  mergeReportReviewRequestPatch,
  mergeReportSamplePatch,
  normalizeReportReviewRequestFields,
  normalizeReportSampleFields
} = require('../contracts/report.contract');
const {
  normalizeQCEvidenceCaptureMetadata
} = require('../contracts/qc-evidence-capture-metadata');
const {
  idempotencyConflict,
  idempotencyReplayUnavailable
} = require('./repository-errors');
const { fingerprintReportCreate } = require('../utils/request-fingerprint');
const { canonicalReportInput } = require('./postgres/mappers');
const {
  collectReportPhotoPaths,
  getQCEvidenceStorage
} = require('../storage/qc-evidence-storage');
const logger = require('../utils/logger');
const { DATA_PROVIDER, STORAGE_PROVIDER } = require('../config/env');

class JsonReportRepository {
  /**
   * @param {string} filePath — path to reports.json
   * @param {object} options
   * @param {Function} [options.now] — clock function
   * @param {string} [options.idempotencyFilePath] — path to idempotency.json;
   *   defaults to <same dir as reports.json>/idempotency.json
   */
  constructor(filePath = REPORTS_FILE, { now = () => new Date(), idempotencyFilePath } = {}) {
    this.filePath = filePath;
    this.now = now;
    this._inMemoryData = null;
    this.idempotencyFilePath = idempotencyFilePath
      || path.join(path.dirname(filePath), 'idempotency.json');
  }

  // ── Reports store ──────────────────────────────────────────────────────────

  _readIdempotency() {
    try {
      if (!fs.existsSync(this.idempotencyFilePath)) return {};
      const raw = fs.readFileSync(this.idempotencyFilePath, 'utf-8');
      return JSON.parse(raw);
    } catch (_) {
      return {};
    }
  }

  _writeIdempotency(data) {
    const tempPath = `${this.idempotencyFilePath}.${Date.now()}.tmp`;
    try {
      const dir = path.dirname(this.idempotencyFilePath);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(tempPath, JSON.stringify(data, null, 2), 'utf-8');
      fs.renameSync(tempPath, this.idempotencyFilePath);
    } catch (e) {
      try { if (fs.existsSync(tempPath)) fs.unlinkSync(tempPath); } catch (_) {}
      throw e;
    }
  }

  _read() {
    if (this._inMemoryData) return this._inMemoryData;
    let reports;
    try {
      if (!fs.existsSync(this.filePath)) {
        reports = [];
      } else {
        const raw = fs.readFileSync(this.filePath, 'utf-8');
        reports = JSON.parse(raw);
      }
    } catch (e) {
      reports = [];
    }
    this._inMemoryData = reports.map(report => ({
      ...report,
      ...normalizeReportSampleFields(report),
      ...normalizeReportReviewRequestFields(report, { tolerateInvalidLegacy: true })
    }));
    return this._inMemoryData;
  }

  _write(data) {
    this._inMemoryData = data;
    const tempPath = `${this.filePath}.${Date.now()}.tmp`;
    try {
      const dir = path.dirname(this.filePath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(tempPath, JSON.stringify(data, null, 2), 'utf-8');
      fs.renameSync(tempPath, this.filePath);
    } catch (e) {
      try {
        if (fs.existsSync(tempPath)) {
          fs.unlinkSync(tempPath);
        }
      } catch (_) {}
      logger.warn('json_storage_write_bypassed', {
        resource: 'reports',
        error_name: e.name || 'Error'
      });
    }
  }

  findAll() {
    return this._read();
  }

  findById(id) {
    const reports = this._read();
    return reports.find(r => r.id === id);
  }

  isTemplateInUse(templateId) {
    const reports = this._read();
    return reports.some(r => r.template_id === templateId);
  }

  create(report) {
    const reports = this._read();
    if (reports.some(r => r.id === report.id)) {
      const err = new Error(`Laporan dengan ID ${report.id} sudah ada.`);
      err.statusCode = 409;
      throw err;
    }
    const metadataNormalized = normalizeQCEvidenceCaptureMetadata(report, {
      now: this.now
    });
    const normalized = {
      ...metadataNormalized,
      ...normalizeReportSampleFields(metadataNormalized),
      ...normalizeReportReviewRequestFields(metadataNormalized)
    };
    reports.push(normalized);
    this._write(reports);
    return normalized;
  }

  /**
   * Idempotent create with persistent local state.
   *
   * The idempotency store is data/idempotency.json (configurable via
   * idempotencyFilePath constructor option). It survives process restarts.
   * Because the JSON provider is single-process local dev, no locking is
   * required — Node.js is single-threaded.
   *
   * @param {object} input — raw payload
   * @param {string} key — Idempotency-Key value
   * @returns {{ report: object, replayed: boolean }}
   */
  createWithIdempotency(input, key) {
    const canonical = canonicalReportInput(normalizeQCEvidenceCaptureMetadata(input, {
      now: this.now
    }));
    const fingerprint = fingerprintReportCreate(canonical);
    const scope = 'create_report';
    const storeKey = `${scope}::${key}`;

    const store = this._readIdempotency();
    const existing = store[storeKey];

    if (existing) {
      if (existing.request_hash !== fingerprint) {
        throw idempotencyConflict();
      }
      // completed — replay
      const original = this.findById(existing.resource_id);
      if (!original) throw idempotencyReplayUnavailable();
      return { report: original, replayed: true };
    }

    const created = this.create(canonical);
    store[storeKey] = { request_hash: fingerprint, resource_id: created.id };
    this._writeIdempotency(store);
    return { report: created, replayed: false };
  }

  update(id, patchData) {
    const reports = this._read();
    const index = reports.findIndex(r => r.id === id);
    if (index === -1) {
      const err = new Error(`Laporan dengan ID ${id} tidak ditemukan.`);
      err.statusCode = 404;
      throw err;
    }
    const merged = {
      ...reports[index],
      ...patchData,
      id // Ensure ID is never changed
    };
    if (patchData.sampleCount !== undefined && patchData.sample_count === undefined) {
      merged.sample_count = patchData.sampleCount;
    }
    if (patchData.samples !== undefined) {
      merged.samples = mergeReportSamplePatch(reports[index].samples, patchData.samples);
    }
    Object.assign(merged, mergeReportReviewRequestPatch(reports[index], patchData));
    const metadataNormalized = normalizeQCEvidenceCaptureMetadata(merged, {
      existingReport: reports[index],
      now: this.now
    });
    const updated = {
      ...metadataNormalized,
      ...normalizeReportSampleFields(metadataNormalized),
      ...normalizeReportReviewRequestFields(metadataNormalized)
    };
    reports[index] = updated;
    this._write(reports);
    return updated;
  }

  async delete(id, { storageProvider = getQCEvidenceStorage, requestId = null } = {}) {
    const reports = this._read();
    const index = reports.findIndex(report => report.id === id);
    if (index === -1) {
      const err = new Error(`Laporan dengan ID ${id} tidak ditemukan.`);
      err.statusCode = 404;
      throw err;
    }
    const photoPaths = collectReportPhotoPaths(reports[index]);
    reports.splice(index, 1);
    this._write(reports);

    const store = this._readIdempotency();
    for (const [key, value] of Object.entries(store)) {
      if (value.resource_id === id) delete store[key];
    }
    // ponytail: two JSON files are not crash-atomic; use PostgreSQL when that matters.
    this._writeIdempotency(store);

    if (photoPaths.length > 0) {
      try {
        await storageProvider().remove(photoPaths);
      } catch (error) {
        logger.warn('storage_cleanup_failed', {
          request_id: requestId,
          report_id: id,
          object_count: photoPaths.length,
          storage_provider: STORAGE_PROVIDER ||
            (DATA_PROVIDER === 'json' ? 'local' : 'unconfigured'),
          error_name: error.name || 'Error'
        });
      }
    }
  }
}

const repository = new JsonReportRepository();
repository.JsonReportRepository = JsonReportRepository;
module.exports = repository;
