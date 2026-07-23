const { reportRepository } = require('../repositories');
const {
  normalizeReportReviewRequestFields,
  normalizeReportSampleFields
} = require('../contracts/report.contract');

const validateObjectBody = (req, res, next) => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return res.status(400).json({ error: 'Request body must be a non-array JSON object' });
  }
  next();
};

const validateAndNormalizeSampleInput = (reportData, { patch = false } = {}) => {
  const hasSampleCount = reportData.sample_count !== undefined ||
    reportData.sampleCount !== undefined;
  const hasSamples = reportData.samples !== undefined;
  if (patch && !hasSampleCount && !hasSamples) return;

  const normalized = normalizeReportSampleFields({
    sample_count: hasSampleCount
      ? (reportData.sample_count ?? reportData.sampleCount)
      : undefined,
    samples: hasSamples ? reportData.samples : []
  });

  if (!patch || hasSampleCount) reportData.sample_count = normalized.sample_count;
  if (!patch || hasSamples) reportData.samples = normalized.samples;
  delete reportData.sampleCount;
};

const getReports = async (req, res, next) => {
  try {
    const reports = await reportRepository.findAll();
    res.json(reports);
  } catch (err) {
    next(err);
  }
};

const getReportById = async (req, res, next) => {
  try {
    const report = await reportRepository.findById(req.params.id);
    if (!report) {
      return res.status(404).json({ error: `Report with ID ${req.params.id} not found` });
    }
    res.json(report);
  } catch (err) {
    next(err);
  }
};

const createReport = async (req, res, next) => {
  try {
    const reportData = req.body;
    
    // Auto-generate report id if missing
    if (!reportData.id) {
      reportData.id = `QC-REP-${Date.now()}`;
    }

    // Validate status if provided
    const VALID_STATUSES = ['DRAFT', 'SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED'];
    if (reportData.status && !VALID_STATUSES.includes(reportData.status)) {
      return res.status(400).json({ 
        error: `Invalid status: ${reportData.status}. Allowed values: ${VALID_STATUSES.join(', ')}` 
      });
    }

    validateAndNormalizeSampleInput(reportData);
    Object.assign(reportData, normalizeReportReviewRequestFields(reportData));
    const created = await reportRepository.create(reportData);
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
};

const patchReport = async (req, res, next) => {
  try {
    const VALID_STATUSES = ['DRAFT', 'SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED'];
    if (req.body.status && !VALID_STATUSES.includes(req.body.status)) {
      return res.status(400).json({ 
        error: `Invalid status: ${req.body.status}. Allowed values: ${VALID_STATUSES.join(', ')}` 
      });
    }

    validateAndNormalizeSampleInput(req.body, { patch: true });
    const updated = await reportRepository.update(req.params.id, req.body);
    res.json(updated);
  } catch (err) {
    next(err);
  }
};

const deleteReport = async (req, res, next) => {
  try {
    await reportRepository.delete(req.params.id);
    res.status(204).end();
  } catch (err) {
    next(err);
  }
};

module.exports = {
  validateObjectBody,
  validateAndNormalizeSampleInput,
  getReports,
  getReportById,
  createReport,
  patchReport,
  deleteReport
};
