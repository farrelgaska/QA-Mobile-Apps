import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/services/qc_local_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('local draft round-trips with an update timestamp', () async {
    const store = QCLocalDraftStore();

    await store.write('user:site:material:template:new', {
      'value': '-2.5',
      'status': 'fail',
    });
    final restored = await store.read('user:site:material:template:new');

    expect(restored, isNotNull);
    expect(restored!.payload, {'value': '-2.5', 'status': 'fail'});
    expect(restored.updatedAt, isA<DateTime>());
  });

  test('draft identities are isolated and deletion is scoped', () async {
    const store = QCLocalDraftStore();
    await store.write('material:one', {'value': 'A'});
    await store.write('material:two', {'value': 'B'});

    await store.delete('material:one');

    expect(await store.read('material:one'), isNull);
    expect((await store.read('material:two'))?.payload['value'], 'B');
  });
}
