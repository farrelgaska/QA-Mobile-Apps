const reportRepository = require('../repositories/json-report.repository');

const validateObjectBody = (req, res, next) => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return res.status(400).json({ error: 'Request body must be a non-array JSON object' });
  }
  next();
};

const getReports = (req, res, next) => {
  try {
    const reports = reportRepository.findAll();
    res.json(reports);
  } catch (err) {
    next(err);
  }
};

const getReportById = (req, res, next) => {
  try {
    const report = reportRepository.findById(req.params.id);
    if (!report) {
      return res.status(404).json({ error: `Report with ID ${req.params.id} not found` });
    }
    res.json(report);
  } catch (err) {
    next(err);
  }
};

const createReport = (req, res, next) => {
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

    const created = reportRepository.create(reportData);
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
};

const patchReport = (req, res, next) => {
  try {
    const VALID_STATUSES = ['DRAFT', 'SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED'];
    if (req.body.status && !VALID_STATUSES.includes(req.body.status)) {
      return res.status(400).json({ 
        error: `Invalid status: ${req.body.status}. Allowed values: ${VALID_STATUSES.join(', ')}` 
      });
    }

    const updated = reportRepository.update(req.params.id, req.body);
    res.json(updated);
  } catch (err) {
    next(err);
  }
};

module.exports = {
  validateObjectBody,
  getReports,
  getReportById,
  createReport,
  patchReport
};
