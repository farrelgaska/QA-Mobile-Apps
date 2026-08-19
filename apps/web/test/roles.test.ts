import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ADMIN_ROLE,
  STAFF_WAREHOUSE_ROLE,
  canCreateQCReports,
  canReviewQCReports,
  canSubmitQCReports,
  isStaffWarehouseRole,
  roleDisplayLabel,
} from '../src/utils/roles.ts';

test('legacy QA Staff values render as Staff Warehouse', () => {
  for (const role of ['QA_STAFF', 'qa_staff', 'QA Staff', 'Staff QA']) {
    assert.equal(isStaffWarehouseRole(role), true, role);
    assert.equal(roleDisplayLabel(role), 'Staff Warehouse');
  }
});

test('Staff Warehouse can create and submit but cannot review reports', () => {
  assert.equal(canCreateQCReports(STAFF_WAREHOUSE_ROLE), true);
  assert.equal(canSubmitQCReports(STAFF_WAREHOUSE_ROLE), true);
  assert.equal(canReviewQCReports(STAFF_WAREHOUSE_ROLE), false);
});

test('Admin remains the only supported report reviewer', () => {
  assert.equal(canReviewQCReports(ADMIN_ROLE), true);
  assert.equal(canReviewQCReports('Admin'), true);
  assert.equal(canCreateQCReports(ADMIN_ROLE), false);
  assert.equal(canSubmitQCReports(ADMIN_ROLE), false);
  assert.equal(canReviewQCReports('QA_STAFF'), false);
});
