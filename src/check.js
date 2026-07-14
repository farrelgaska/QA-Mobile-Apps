const fs = require('fs');
const path = require('path');

const reportsPath = path.join(__dirname, '../data/reports.json');
const templatesPath = path.join(__dirname, '../data/templates.json');

try {
  console.log('Checking reports.json...');
  const reportsRaw = fs.readFileSync(reportsPath, 'utf8');
  const reports = JSON.parse(reportsRaw);
  if (!Array.isArray(reports)) {
    throw new Error('reports.json must be a JSON array');
  }
  console.log(`reports.json is valid! (${reports.length} records)`);

  console.log('Checking templates.json...');
  const templatesRaw = fs.readFileSync(templatesPath, 'utf8');
  const templates = JSON.parse(templatesRaw);
  if (!Array.isArray(templates)) {
    throw new Error('templates.json must be a JSON array');
  }
  console.log(`templates.json is valid! (${templates.length} records)`);

  console.log('All JSON files are valid and structural checks passed successfully!');
  process.exit(0);
} catch (err) {
  console.error('Validation check failed:', err.message);
  process.exit(1);
}
