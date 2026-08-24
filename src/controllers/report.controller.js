const { reportRepository, templateRepository } = require('../repositories');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');
const {
  normalizeReportReviewRequestFields,
  normalizeReportSampleFields
} = require('../contracts/report.contract');

const validateObjectBody = (req, res, next) => {
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return next(new AppError({
      status: 400,
      code: 'VALIDATION_ERROR',
      message: 'Data yang dikirim tidak valid.',
      details: [{ path: 'body', message: 'Request body must be a non-array JSON object' }]
    }));
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

const createGetReports = repository => async (req, res, next) => {
  try {
    const reports = await repository.findAll();
    res.json(reports);
  } catch (err) {
    next(err);
  }
};
const getReports = createGetReports(reportRepository);

const getReportById = async (req, res, next) => {
  try {
    const report = await reportRepository.findById(req.params.id);
    if (!report) {
      return next(new AppError({
        status: 404,
        code: 'NOT_FOUND',
        message: `Laporan dengan ID ${req.params.id} tidak ditemukan.`
      }));
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
    const templateId = reportData.template_id || reportData.templateId;
    req.observability = {
      operation: 'report_create',
      report_id: reportData.id,
      template_id: templateId || null
    };

    // Validate status if provided
    const VALID_STATUSES = ['DRAFT', 'SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED'];
    if (reportData.status && !VALID_STATUSES.includes(reportData.status)) {
      return next(new AppError({
        status: 400,
        code: 'VALIDATION_ERROR',
        message: 'Data yang dikirim tidak valid.',
        details: [{ path: 'status', message: `Invalid status: ${reportData.status}. Allowed values: ${VALID_STATUSES.join(', ')}` }]
      }));
    }

    validateAndNormalizeSampleInput(reportData);
    Object.assign(reportData, normalizeReportReviewRequestFields(reportData));

    if (templateId) {
      const template = await templateRepository.findById(templateId);
      if (!template) {
        return next(new AppError({
          status: 400,
          code: 'VALIDATION_ERROR',
          message: 'Data yang dikirim tidak valid.',
          details: [{ path: 'template_id', message: `Template with ID ${templateId} not found` }]
        }));
      }
      if (!template.is_active) {
        return next(new AppError({
          status: 400,
          code: 'VALIDATION_ERROR',
          message: 'Data yang dikirim tidak valid.',
          details: [{ path: 'template_id', message: `Template with ID ${templateId} is inactive and cannot be used for new reports` }]
        }));
      }
      reportData.template_snapshot = template;
    }

    const idempotencyKey = req.idempotencyKey || null;

    if (idempotencyKey) {
      const { report, replayed } = await reportRepository.createWithIdempotency(reportData, idempotencyKey);
      if (replayed) {
        res.set('Idempotency-Replayed', 'true');
        logger.info('idempotency_replay', {
          request_id: req.requestId,
          report_id: report.id,
          idempotency_key_fingerprint: req.idempotencyKeyFingerprint
        });
        return res.status(200).json(report);
      }
      logger.info('report_created', {
        request_id: req.requestId,
        report_id: report.id,
        template_id: templateId || null,
        status: report.status,
        idempotency_state: 'created'
      });
      return res.status(201).json(report);
    }

    // Legacy path: no idempotency key
    const created = await reportRepository.create(reportData);
    logger.info('report_created', {
      request_id: req.requestId,
      report_id: created.id,
      template_id: templateId || null,
      status: created.status,
      idempotency_state: 'not_used'
    });
    res.status(201).json(created);
  } catch (err) {
    next(err);
  }
};


const patchReport = async (req, res, next) => {
  try {
    req.observability = {
      operation: 'report_update',
      report_id: req.params.id
    };
    const VALID_STATUSES = ['DRAFT', 'SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED'];
    if (req.body.status && !VALID_STATUSES.includes(req.body.status)) {
      return next(new AppError({
        status: 400,
        code: 'VALIDATION_ERROR',
        message: 'Data yang dikirim tidak valid.',
        details: [{ path: 'status', message: `Invalid status: ${req.body.status}. Allowed values: ${VALID_STATUSES.join(', ')}` }]
      }));
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
    req.observability = {
      operation: 'report_delete',
      report_id: req.params.id
    };
    await reportRepository.delete(req.params.id, { requestId: req.requestId });
    logger.info('report_deleted', {
      request_id: req.requestId,
      report_id: req.params.id
    });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
};

module.exports = {
  validateObjectBody,
  validateAndNormalizeSampleInput,
  createGetReports,
  getReports,
  getReportById,
  createReport,
  patchReport,
  deleteReport
};
