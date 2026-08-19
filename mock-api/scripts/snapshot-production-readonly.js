const fs = require('node:fs');
const path = require('node:path');

const productionOrigin = 'https://qa-mobile-api.vercel.app';
const outputDirectory = path.resolve(__dirname, '../data');
const allowedEndpoints = new Set(['/templates', '/reports']);
const sensitiveKey = /(token|cookie|password|secret|credential|database.?url|dsn|signed.?url)/i;
const absoluteUrl = /^https?:\/\//i;

function sanitize(value, key = '') {
  if (sensitiveKey.test(key)) return undefined;
  if (typeof value === 'string' && absoluteUrl.test(value)) return undefined;
  if (Array.isArray(value)) {
    return value
      .map(item => sanitize(item, key))
      .filter(item => item !== undefined);
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value)
        .map(([childKey, childValue]) => [
          childKey,
          sanitize(childValue, childKey),
        ])
        .filter(([, childValue]) => childValue !== undefined),
    );
  }
  return value;
}

async function getJson(endpoint) {
  if (!allowedEndpoints.has(endpoint)) {
    throw new Error(`Endpoint is not allow-listed: ${endpoint}`);
  }
  const response = await fetch(`${productionOrigin}${endpoint}`, {
    method: 'GET',
    headers: { accept: 'application/json' },
    redirect: 'error',
  });
  if (!response.ok) {
    throw new Error(`${endpoint} returned HTTP ${response.status}`);
  }
  const value = await response.json();
  if (!Array.isArray(value)) {
    throw new Error(`${endpoint} did not return an array`);
  }
  return sanitize(value);
}

async function main() {
  const [templates, reports] = await Promise.all([
    getJson('/templates'),
    getJson('/reports'),
  ]);
  if (templates.length !== 15 || reports.length !== 15) {
    throw new Error(
      `Unexpected production counts: templates=${templates.length}, reports=${reports.length}`,
    );
  }
  const statusCounts = reports.reduce((counts, report) => {
    counts[report.status] = (counts[report.status] || 0) + 1;
    return counts;
  }, {});
  if (
    statusCounts.SUBMITTED !== 9 ||
    statusCounts.NEEDS_FOLLOW_UP !== 3 ||
    statusCounts.APPROVED !== 3
  ) {
    throw new Error(
      `Unexpected report statuses: ${JSON.stringify(statusCounts)}`,
    );
  }
  fs.writeFileSync(
    path.join(outputDirectory, 'templates.json'),
    `${JSON.stringify(templates, null, 2)}\n`,
  );
  fs.writeFileSync(
    path.join(outputDirectory, 'reports.json'),
    `${JSON.stringify(reports, null, 2)}\n`,
  );
  process.stdout.write(
    `Sanitized production snapshot: templates=${templates.length}, reports=${reports.length}, statuses=${JSON.stringify(statusCounts)}\n`,
  );
}

main().catch(error => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
