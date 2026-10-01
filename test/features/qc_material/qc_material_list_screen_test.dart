import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/services/api_service.dart';
import 'package:mobile/features/qc_material/screens/qc_material_list_screen.dart';
import 'package:mobile/shared/models/qc_material_template_model.dart';

Map<String, dynamic> template(
  String id,
  String name,
  String code,
  String category,
  int checklistCount,
) =>
    {
      'id': id,
      'type': 'MATERIAL',
      'name': name,
      'form_code': code,
      'category': category,
      'description': '',
      'is_active': true,
      'checklist_items': [
        for (var index = 0; index < checklistCount; index++)
          {
            'id': 'item-$index',
            'parameter_name': 'Parameter $index',
            'input_type': 'text',
            'is_required': true,
            'is_active': true,
          },
      ],
    };

Map<String, dynamic> family(String id, String name, String templateId) => {
      'family_id': id,
      'name': name,
      'category': 'CABLE',
      'template_id': templateId,
      'active': true,
    };

void main() {
  testWidgets(
      'cable family cards reuse linked checklists and Tiang stays visible',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.url.path == '/templates') {
        expect(request.url.queryParameters['type'], 'MATERIAL');
        return http.Response(
            jsonEncode([
              template('QC_CABLE_DUCT', 'Kabel Duct', 'TA-FR-048-014-03',
                  'QC Material', 8),
              template('QC_CABLE_AERIAL', 'Kabel Aerial', 'TA-FR-048-014-02',
                  'CABLE', 9),
              template('QC_CABLE_ADSS', 'Kabel ADSS', 'TA-FR-048-014-04',
                  'CABLE', 8),
              template('tiang-7m', 'Tiang 7 Meter', 'QC-TIANG-07', 'POLE', 3),
            ]),
            200);
      }
      if (request.url.path == '/master-data/material-families') {
        expect(request.url.queryParameters['category'], 'CABLE');
        return http.Response(
            jsonEncode([
              family('duct-g652d', 'KD FO Single Mode G 652D', 'QC_CABLE_DUCT'),
              family('duct-g655c', 'KD FO Single Mode G 655C', 'QC_CABLE_DUCT'),
              family(
                  'aerial-g652d', 'KU FO Single Mode G652D', 'QC_CABLE_AERIAL'),
              family('adss-telkom', 'KU FO ADSS G652D Marking Telkom',
                  'QC_CABLE_ADSS'),
            ]),
            200);
      }
      return http.Response('Not found', 404);
    });
    addTearDown(client.close);
    final api = ApiService.withClient(client);
    Object? opened;
    final router = GoRouter(
      initialLocation: '/qc-material',
      routes: [
        GoRoute(
          path: '/qc-material',
          builder: (_, __) => QCMaterialListScreen(apiService: api),
        ),
        GoRoute(
          path: '/qc-material/form/:id',
          builder: (_, state) {
            opened = state.extra;
            return Scaffold(body: Text(state.pathParameters['id']!));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Kabel Duct'), findsNothing);

    final expected = [
      (
        'duct-g652d',
        'KD FO Single Mode G 652D',
        'QC_CABLE_DUCT',
        'TA-FR-048-014-03',
        8
      ),
      (
        'duct-g655c',
        'KD FO Single Mode G 655C',
        'QC_CABLE_DUCT',
        'TA-FR-048-014-03',
        8
      ),
      (
        'aerial-g652d',
        'KU FO Single Mode G652D',
        'QC_CABLE_AERIAL',
        'TA-FR-048-014-02',
        9
      ),
      (
        'adss-telkom',
        'KU FO ADSS G652D Marking Telkom',
        'QC_CABLE_ADSS',
        'TA-FR-048-014-04',
        8
      ),
    ];
    for (final (id, name, templateId, code, count) in expected) {
      final card = find.byKey(ValueKey(id));
      expect(card, findsOneWidget);
      expect(
          find.descendant(of: card, matching: find.text(name)), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('CABLE')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Kode Form: $code')),
          findsOneWidget);
      expect(
          find.descendant(
              of: card, matching: find.text('$count Poin Checklist')),
          findsOneWidget);

      await tester
          .tap(find.descendant(of: card, matching: find.text('Mulai QC')));
      await tester.pumpAndSettle();
      expect(find.text(templateId), findsOneWidget);
      final selected = opened as QCMaterialSelection;
      expect(selected.family.familyId, id);
      expect(selected.template.id, templateId);
      router.pop();
      await tester.pumpAndSettle();
    }

    final tiang = find.byKey(const ValueKey('tiang-7m'));
    expect(tiang, findsOneWidget);
    expect(find.descendant(of: tiang, matching: find.text('Tiang 7 Meter')),
        findsOneWidget);
    expect(
        find.descendant(
            of: tiang, matching: find.text('Kode Form: QC-TIANG-07')),
        findsOneWidget);
    expect(find.descendant(of: tiang, matching: find.text('3 Poin Checklist')),
        findsOneWidget);
    await tester
        .tap(find.descendant(of: tiang, matching: find.text('Mulai QC')));
    await tester.pumpAndSettle();
    expect(find.text('tiang-7m'), findsOneWidget);
    expect(opened, isA<QCMaterialTemplate>());
  });
}
