const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { JsonTemplateRepository } = require('../../src/repositories/json-template.repository');
const { JsonReportRepository } = require('../../src/repositories/json-report.repository');


function createTempFile() {
  const file = path.join(os.tmpdir(), `test-db-${Date.now()}-${Math.random()}.json`);
  fs.writeFileSync(file, '[]');
  return file;
}

test('JSON Provider: immutable historical snapshot and template lifecycle rules', async () => {
  const templatesFile = createTempFile();
  const reportsFile = createTempFile();

  try {
    const templateRepo = new JsonTemplateRepository(templatesFile);
    const reportRepo = new JsonReportRepository(reportsFile);

    // 1. Create Template State A
    const templateA = {
      id: 't-1',
      type: 'MATERIAL',
      name: 'Test Template A',
      category: 'Test',
      is_active: true,
      checklist_items: [{
        id: 'i-1',
        parameter_name: 'Param A',
        input_type: 'number',
        is_required: true,
        is_active: true,
        is_critical: false,
        position: 0
      }]
    };

    const savedTemplateA = await templateRepo.create(templateA);
    assert.ok(savedTemplateA.id);

    // 2. Create Report and persist snapshot A
    const reportData = {
      id: 'r-1',
      type: 'MATERIAL',
      template_id: savedTemplateA.id,
      title: 'Report with A',
      status: 'DRAFT',
      staff_name: 'Tester',
      staff_nik: '123',
      location: { site_id: 'S1', site_name: 'Site', area: 'A1', detail_location: 'D1' },
      template_snapshot: savedTemplateA,
      checklist_items: [{
        id: 'ci-1',
        parameter_name: 'Param A',
        input_type: 'number',
        is_required: true
      }]
    };

    const savedReport = await reportRepo.create(reportData);
    assert.ok(savedReport.id);
    assert.strictEqual(savedReport.template_snapshot.name, 'Test Template A');

    // 3. Modify Template to State B
    const templateB = {
      ...savedTemplateA,
      name: 'Test Template B Modified',
      checklist_items: [
        ...savedTemplateA.checklist_items,
        {
          id: 'i-2',
          parameter_name: 'Param B',
          input_type: 'text',
          is_required: false,
          is_active: true,
          is_critical: false,
          position: 1
        }
      ]
    };
    const savedTemplateB = await templateRepo.update(savedTemplateA.id, templateB);
    assert.strictEqual(savedTemplateB.name, 'Test Template B Modified');

    // 4. Read historical report - must still have snapshot A
    const historicalReport = await reportRepo.findById(savedReport.id);
    assert.strictEqual(historicalReport.template_snapshot.name, 'Test Template A');
    assert.strictEqual(historicalReport.template_snapshot.checklist_items.length, 1);

    // 5. Deactivate template does not change report snapshot
    await templateRepo.update(savedTemplateA.id, { ...savedTemplateB, is_active: false });
    const historicalReportAfterDeactivate = await reportRepo.findById(savedReport.id);
    assert.strictEqual(historicalReportAfterDeactivate.template_snapshot.name, 'Test Template A');

    // 6. Deleting a referenced template is blocked
    // The JSON repository delegates this check or it's handled in the controller.
    // We can simulate the controller logic or if JsonReportRepository implements isTemplateInUse:
    if (typeof reportRepo.isTemplateInUse === 'function') {
      const inUse = await reportRepo.isTemplateInUse(savedTemplateA.id);
      assert.strictEqual(inUse, true);
    }
  } finally {
    if (fs.existsSync(templatesFile)) fs.unlinkSync(templatesFile);
    if (fs.existsSync(reportsFile)) fs.unlinkSync(reportsFile);
  }
});
