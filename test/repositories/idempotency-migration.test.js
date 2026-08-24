const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

test('idempotency follow-up migration removes orphans and cascades report deletes', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../../supabase/migrations/20260824000100_cascade_report_idempotency.sql'),
    'utf8'
  ).toLowerCase();

  assert.match(sql, /delete from public\.api_idempotency_keys/);
  assert.match(sql, /foreign key \(resource_id\) references public\.qc_reports\(id\)/);
  assert.match(sql, /on delete cascade/);
  assert.match(sql, /deferrable initially deferred/);
});
