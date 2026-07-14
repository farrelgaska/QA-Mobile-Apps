const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3002;
const REPORTS_FILE = path.join(__dirname, '../data/reports.json');
const TEMPLATES_FILE = path.join(__dirname, '../data/templates.json');

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

const readTemplates = () => {
  try {
    const raw = fs.readFileSync(TEMPLATES_FILE, 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    console.error('Error reading templates.json:', e);
    return [];
  }
};

const writeTemplates = (data) => {
  try {
    fs.writeFileSync(TEMPLATES_FILE, JSON.stringify(data, null, 2), 'utf-8');
  } catch (e) {
    console.error('Error writing to templates.json:', e);
  }
};

// GET /templates
app.get('/templates', (req, res) => {
  try {
    const templates = readTemplates();
    res.json(templates);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// POST /templates
app.post('/templates', (req, res) => {
  try {
    const templates = readTemplates();
    const templateData = req.body;

    if (!templateData || typeof templateData !== 'object') {
      return res.status(400).json({ error: 'Invalid template data payload' });
    }

    // Auto-generate template id if missing
    if (!templateData.id) {
      templateData.id = `WRK-${Date.now()}`;
    }

    const index = templates.findIndex(t => t.id === templateData.id);
    if (index !== -1) {
      templates[index] = { ...templates[index], ...templateData };
      writeTemplates(templates);
      return res.status(201).json(templates[index]);
    }

    templates.push(templateData);
    writeTemplates(templates);
    res.status(201).json(templateData);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// DELETE /templates/:templateId/items/:itemId
app.delete('/templates/:templateId/items/:itemId', (req, res) => {
  try {
    const { templateId, itemId } = req.params;
    const templates = readTemplates();
    const templateIndex = templates.findIndex(t => t.id === templateId);

    if (templateIndex === -1) {
      return res.status(404).json({ error: `Template with ID ${templateId} not found` });
    }

    const template = templates[templateIndex];
    const itemIndex = template.checklistItems.findIndex(item => item.id === itemId);

    if (itemIndex === -1) {
      return res.status(404).json({ error: `Checklist parameter with ID ${itemId} not found in template ${templateId}` });
    }

    // Remove only the selected checklist parameter
    template.checklistItems.splice(itemIndex, 1);
    template.updatedAt = new Date().toISOString();

    writeTemplates(templates);
    res.status(200).json(template);
  } catch (err) {
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// PATCH /templates/:id
app.patch('/templates/:id', (req, res) => {
  try {
    const { id } = req.params;
    const patchData = req.body;

    if (!patchData || typeof patchData !== 'object') {
      return res.status(400).json({ error: 'Invalid patch payload' });
    }

    const templates = readTemplates();
    const index = templates.findIndex(t => t.id === id);

    if (index === -1) {
      return res.status(404).json({ error: `Template with ID ${id} not found` });
    }

    const updatedTemplate = {
      ...templates[index],
      ...patchData,
      updatedAt: new Date().toISOString()
    };
    updatedTemplate.id = id; // Ensure ID is not changed

    templates[index] = updatedTemplate;
    writeTemplates(templates);

    res.status(200).json(updatedTemplate);
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
