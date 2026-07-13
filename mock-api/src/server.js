const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3002;
const REPORTS_FILE = path.join(__dirname, '../data/reports.json');

app.use(cors());
app.use(express.json());

// Helper to read data
const readReports = () => {
  try {
    const raw = fs.readFileSync(REPORTS_FILE, 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    console.error('Error reading reports.json:', e);
    return [];
  }
};

// Helper to write data
const writeReports = (data) => {
  try {
    fs.writeFileSync(REPORTS_FILE, JSON.stringify(data, null, 2), 'utf-8');
  } catch (e) {
    console.error('Error writing to reports.json:', e);
  }
};

// Helper to validate status codes
const VALID_STATUSES = ['DRAFT', 'SUBMITTED', 'NEEDS_FOLLOW_UP', 'APPROVED'];

// GET /reports
app.get('/reports', (req, res) => {
  try {
    const reports = readReports();
    res.json(reports);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// GET /reports/:id
app.get('/reports/:id', (req, res) => {
  try {
    const reports = readReports();
    const report = reports.find(r => r.id === req.params.id);
    if (!report) {
      return res.status(404).json({ error: `Report with ID ${req.params.id} not found` });
    }
    res.json(report);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// POST /reports
app.post('/reports', (req, res) => {
  try {
    const reports = readReports();
    const reportData = req.body;

    if (!reportData || typeof reportData !== 'object') {
      return res.status(400).json({ error: 'Invalid report data payload' });
    }

    // Auto-generate report id if missing
    if (!reportData.id) {
      reportData.id = `QC-REP-${Date.now()}`;
    }

    // Validate status if provided
    if (reportData.status && !VALID_STATUSES.includes(reportData.status)) {
      return res.status(400).json({ error: `Invalid status: ${reportData.status}. Allowed values: ${VALID_STATUSES.join(', ')}` });
    }

    const index = reports.findIndex(r => r.id === reportData.id);
    if (index !== -1) {
      reports[index] = { ...reports[index], ...reportData };
      writeReports(reports);
      return res.status(200).json(reports[index]);
    }

    reports.push(reportData);
    writeReports(reports);
    res.status(201).json(reportData);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// PATCH /reports/:id
app.patch('/reports/:id', (req, res) => {
  try {
    const reports = readReports();
    const index = reports.findIndex(r => r.id === req.params.id);
    if (index === -1) {
      return res.status(404).json({ error: `Report with ID ${req.params.id} not found` });
    }

    const patchData = req.body;
    if (!patchData || typeof patchData !== 'object') {
      return res.status(400).json({ error: 'Invalid patch payload' });
    }

    // Validate status if patched
    if (patchData.status && !VALID_STATUSES.includes(patchData.status)) {
      return res.status(400).json({ error: `Invalid status: ${patchData.status}. Allowed values: ${VALID_STATUSES.join(', ')}` });
    }

    reports[index] = { ...reports[index], ...patchData };
    writeReports(reports);
    res.json(reports[index]);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// 404 Route handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

app.listen(PORT, () => {
  console.log(`[Mock API Backend] Running on http://localhost:${PORT}`);
});
