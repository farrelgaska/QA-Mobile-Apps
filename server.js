const http = require('http');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'db.json');

const getReports = () => {
  try {
    const raw = fs.readFileSync(DB_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    console.error('Error reading db.json:', e);
    return [];
  }
};

const saveReports = (data) => {
  try {
    fs.writeFileSync(DB_PATH, JSON.stringify(data, null, 2), 'utf-8');
  } catch (e) {
    console.error('Error writing to db.json:', e);
  }
};

const TEMPLATES_PATH = path.join(__dirname, 'data', 'templates.json');

const getTemplates = () => {
  try {
    const raw = fs.readFileSync(TEMPLATES_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    console.error('Error reading templates.json:', e);
    return [];
  }
};

const saveTemplates = (data) => {
  try {
    const dir = path.dirname(TEMPLATES_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(TEMPLATES_PATH, JSON.stringify(data, null, 2), 'utf-8');
  } catch (e) {
    console.error('Error writing to templates.json:', e);
  }
};

const server = http.createServer((req, res) => {
  // Setup CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Parse path and query params
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;

  // GET /reports
  if (pathname === '/reports' && req.method === 'GET') {
    const reports = getReports();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(reports));
    return;
  }

  // GET /reports/:id
  if (pathname.startsWith('/reports/') && req.method === 'GET') {
    const id = pathname.substring(9);
    const reports = getReports();
    const report = reports.find(r => r.id === id);
    if (report) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(report));
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Report not found' }));
    }
    return;
  }

  // POST /reports
  if (pathname === '/reports' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const newReport = JSON.parse(body);
        if (!newReport.id) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Report must have an id' }));
          return;
        }
        const reports = getReports();
        const existingIdx = reports.findIndex(r => r.id === newReport.id);
        if (existingIdx !== -1) {
          reports[existingIdx] = newReport;
        } else {
          reports.push(newReport);
        }
        saveReports(reports);
        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(newReport));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON body' }));
      }
    });
    return;
  }

  // PATCH /reports/:id
  if (pathname.startsWith('/reports/') && req.method === 'PATCH') {
    const id = pathname.substring(9);
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const patchData = JSON.parse(body);
        const reports = getReports();
        const existingIdx = reports.findIndex(r => r.id === id);
        if (existingIdx === -1) {
          res.writeHead(404, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Report not found' }));
          return;
        }
        reports[existingIdx] = { ...reports[existingIdx], ...patchData };
        saveReports(reports);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(reports[existingIdx]));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON body' }));
      }
    });
    return;
  }

  // GET /templates
  if (pathname === '/templates' && req.method === 'GET') {
    const templates = getTemplates();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(templates));
    return;
  }

  // GET /templates/:id
  if (pathname.startsWith('/templates/') && req.method === 'GET') {
    const id = pathname.substring(11);
    const templates = getTemplates();
    const template = templates.find(t => t.id === id);
    if (template) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(template));
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Template not found' }));
    }
    return;
  }

  // POST /templates
  if (pathname === '/templates' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const newTemplate = JSON.parse(body);
        const id = newTemplate.id || `template_${Date.now()}`;
        const templates = getTemplates();
        
        if (templates.some(t => t.id === id)) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Template with this id already exists' }));
          return;
        }

        const nowIso = new Date().toISOString();
        const template = {
          id,
          type: newTemplate.type || 'MATERIAL',
          name: newTemplate.name || '',
          formCode: newTemplate.formCode || '',
          category: newTemplate.category || '',
          standardCode: newTemplate.standardCode || '',
          checklistItems: newTemplate.checklistItems || [],
          isActive: newTemplate.isActive !== undefined ? newTemplate.isActive : true,
          createdAt: nowIso,
          updatedAt: nowIso
        };

        templates.push(template);
        saveTemplates(templates);

        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(template));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON body' }));
      }
    });
    return;
  }

  // PATCH /templates/:id
  if (pathname.startsWith('/templates/') && req.method === 'PATCH') {
    const id = pathname.substring(11);
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const patchData = JSON.parse(body);
        const templates = getTemplates();
        const existingIdx = templates.findIndex(t => t.id === id);
        if (existingIdx === -1) {
          res.writeHead(404, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'Template not found' }));
          return;
        }

        const updatedTemplate = {
          ...templates[existingIdx],
          ...patchData,
          updatedAt: new Date().toISOString()
        };

        updatedTemplate.id = id; // Ensure id is not changed by PATCH

        templates[existingIdx] = updatedTemplate;
        saveTemplates(templates);

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(updatedTemplate));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Invalid JSON body' }));
      }
    });
    return;
  }

  // Fallback 404
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Route not found' }));
});

const PORT = 3001;
server.listen(PORT, () => {
  console.log(`[Mock API] Listening at http://localhost:${PORT}`);
});
