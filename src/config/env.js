const path = require('path');
const dotenv = require('dotenv');

// Load environment variables from .env
dotenv.config({ path: path.join(__dirname, '../../.env') });

const PORT = parseInt(process.env.PORT || '3002', 10);
const CORS_ORIGINS = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(',').map(o => o.trim())
  : ['http://localhost:5173', 'http://localhost:3000'];

const REPORTS_FILE = path.join(__dirname, '../../data/reports.json');
const TEMPLATES_FILE = path.join(__dirname, '../../data/templates.json');

module.exports = {
  PORT,
  CORS_ORIGINS,
  REPORTS_FILE,
  TEMPLATES_FILE
};
