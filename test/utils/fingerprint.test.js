const { fingerprintReportCreate, sortedKeys } = require('../../src/utils/request-fingerprint');
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

describe('Request Fingerprinting', () => {
  const basePayload = {
    id: 'QC-REP-123',
    type: 'MATERIAL',
    template_id: 'TMP-01',
    status: 'SUBMITTED',
    checklist_items: [
      { id: 'item-1', actual_value: 'OK', item_photos: ['path/1.jpg'] },
      { id: 'item-2', actual_value: 'NOK', item_photos: [] }
    ],
    samples: [
      {
        id: 'samp-1',
        checklist_answers: [
          { checklist_item_id: 'i-1', actual_value: '10' }
        ]
      }
    ]
  };

  it('generates the same fingerprint regardless of object key order', () => {
    const payload1 = {
      id: 'QC-REP-123',
      template_id: 'TMP-01',
      status: 'SUBMITTED',
      type: 'MATERIAL'
    };

    // different key insertion order
    const payload2 = {
      status: 'SUBMITTED',
      type: 'MATERIAL',
      template_id: 'TMP-01',
      id: 'QC-REP-123'
    };

    const hash1 = fingerprintReportCreate(payload1);
    const hash2 = fingerprintReportCreate(payload2);
    assert.equal(hash1, hash2);
  });

  it('generates different fingerprints for semantically different payloads', () => {
    const originalHash = fingerprintReportCreate(basePayload);

    // Change a checklist answer
    const modifiedPayload1 = JSON.parse(JSON.stringify(basePayload));
    modifiedPayload1.checklist_items[0].actual_value = 'CHANGED';
    assert.notEqual(fingerprintReportCreate(modifiedPayload1), originalHash);

    // Change a sample answer
    const modifiedPayload2 = JSON.parse(JSON.stringify(basePayload));
    modifiedPayload2.samples[0].checklist_answers[0].actual_value = '11';
    assert.notEqual(fingerprintReportCreate(modifiedPayload2), originalHash);
  });

  it('ignores server-computed and excluded fields', () => {
    const originalHash = fingerprintReportCreate(basePayload);

    const payloadWithExcluded = JSON.parse(JSON.stringify(basePayload));
    // These should be excluded by canonicalFingerprintPayload
    payloadWithExcluded.template_snapshot = { id: 'TMP-01', name: 'Mock' };
    payloadWithExcluded.migration_metadata = { version: 2 };
    payloadWithExcluded.created_at = '2026-08-22T00:00:00Z';
    payloadWithExcluded.updated_at = '2026-08-22T00:00:00Z';

    const hash2 = fingerprintReportCreate(payloadWithExcluded);
    assert.equal(hash2, originalHash);
  });

  it('preserves array order', () => {
    const payload1 = {
      id: '1',
      samples: [{ id: 's1' }, { id: 's2' }]
    };
    const payload2 = {
      id: '1',
      samples: [{ id: 's2' }, { id: 's1' }] // swapped
    };

    assert.notEqual(fingerprintReportCreate(payload1), fingerprintReportCreate(payload2));
  });
});
