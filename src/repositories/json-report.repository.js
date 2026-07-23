const fs = require('fs');
const path = require('path');
const { REPORTS_FILE } = require('../config/env');
const {
  mergeReportSamplePatch,
  normalizeReportSampleFields
} = require('../contracts/report.contract');

class JsonReportRepository {
  constructor(filePath = REPORTS_FILE) {
    this.filePath = filePath;
  }

  _read() {
    let reports;
    try {
      if (!fs.existsSync(this.filePath)) {
        const dir = path.dirname(this.filePath);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
        this._write([]);
        return [];
      }
      const raw = fs.readFileSync(this.filePath, 'utf-8');
      reports = JSON.parse(raw);
    } catch (e) {
      throw new Error(`Failed to read reports database: ${e.message}`);
    }
    return reports.map(report => ({
      ...report,
      ...normalizeReportSampleFields(report)
    }));
  }

  _write(data) {
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
      throw new Error(`Failed to write reports database: ${e.message}`);
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
    const normalized = {
      ...report,
      ...normalizeReportSampleFields(report)
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
    const updated = {
      ...merged,
      ...normalizeReportSampleFields(merged)
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
