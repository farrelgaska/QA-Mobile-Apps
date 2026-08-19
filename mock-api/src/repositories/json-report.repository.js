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

class JsonReportRepository {
  constructor(filePath = REPORTS_FILE, { now = () => new Date() } = {}) {
    this.filePath = filePath;
    this.now = now;
    this._inMemoryData = null;
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
      console.warn(`[JsonReportRepository] Disk write bypassed (${e.message}). Data kept in memory.`);
    }
  }

  findAll() {
    return this._read();
  }

  findById(id) {
    const reports = this._read();
    return reports.find(r => r.id === id);
  }

  create(report) {
    const reports = this._read();
    if (reports.some(r => r.id === report.id)) {
      const err = new Error(`Report with ID ${report.id} already exists`);
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

  update(id, patchData) {
    const reports = this._read();
    const index = reports.findIndex(r => r.id === id);
    if (index === -1) {
      const err = new Error(`Report with ID ${id} not found`);
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

  delete(id) {
    const reports = this._read();
    const index = reports.findIndex(report => report.id === id);
    if (index === -1) {
      const err = new Error(`Report with ID ${id} not found`);
      err.statusCode = 404;
      throw err;
    }
    reports.splice(index, 1);
    this._write(reports);
  }
}

const repository = new JsonReportRepository();
repository.JsonReportRepository = JsonReportRepository;
module.exports = repository;
