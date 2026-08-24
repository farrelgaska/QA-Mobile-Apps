import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/utils/request_fingerprint.dart';

void main() {
  group('Semantic Fingerprint', () {
    final basePayload = {
      'id': 'QC-REP-123',
      'type': 'MATERIAL',
      'template_id': 'TMP-01',
      'status': 'SUBMITTED',
      'checklist_items': [
        {'id': 'item-1', 'actual_value': 'OK', 'item_photos': ['path/1.jpg']},
        {'id': 'item-2', 'actual_value': 'NOK', 'item_photos': []}
      ],
      'samples': [
        {
          'id': 'samp-1',
          'checklist_answers': [
            {'checklist_item_id': 'i-1', 'actual_value': '10'}
          ]
        }
      ]
    };

    test('generates same fingerprint for different key insertion order', () {
      final payload1 = {
        'id': 'QC-REP-123',
        'template_id': 'TMP-01',
        'status': 'SUBMITTED',
        'type': 'MATERIAL'
      };

      final payload2 = {
        'status': 'SUBMITTED',
        'type': 'MATERIAL',
        'template_id': 'TMP-01',
        'id': 'QC-REP-123'
      };

      final hash1 = generateSemanticFingerprint(payload1);
      final hash2 = generateSemanticFingerprint(payload2);
      expect(hash1, equals(hash2));
    });

    test('generates same fingerprint for rebuilt objects', () {
      final payloadClone = jsonDecode(jsonEncode(basePayload)) as Map<String, dynamic>;
      
      final hash1 = generateSemanticFingerprint(basePayload);
      final hash2 = generateSemanticFingerprint(payloadClone);
      expect(hash1, equals(hash2));
    });

    test('generates different fingerprints for semantic changes', () {
      final hash1 = generateSemanticFingerprint(basePayload);

      final payloadChangeItem = jsonDecode(jsonEncode(basePayload)) as Map<String, dynamic>;
      payloadChangeItem['checklist_items'][0]['actual_value'] = 'CHANGED';
      expect(generateSemanticFingerprint(payloadChangeItem), isNot(equals(hash1)));

      final payloadChangeSample = jsonDecode(jsonEncode(basePayload)) as Map<String, dynamic>;
      payloadChangeSample['samples'][0]['checklist_answers'][0]['actual_value'] = '11';
      expect(generateSemanticFingerprint(payloadChangeSample), isNot(equals(hash1)));
    });

    test('ignores excluded transient fields', () {
      final originalHash = generateSemanticFingerprint(basePayload);

      final payloadWithTransient = jsonDecode(jsonEncode(basePayload)) as Map<String, dynamic>;
      payloadWithTransient['template_snapshot'] = {'id': 'TMP-01'};
      payloadWithTransient['migration_metadata'] = {'v': 1};
      payloadWithTransient['created_at'] = '2026-08-22T00:00:00Z';
      payloadWithTransient['submitted_at'] = '2026-08-22T00:00:00Z';

      expect(generateSemanticFingerprint(payloadWithTransient), equals(originalHash));
    });
  });
}
