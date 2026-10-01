import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/constants/app_colors.dart';
import 'package:mobile/shared/widgets/master_data_search_field.dart';

Widget field({
  required Future<List<String>> Function(String) search,
  ValueChanged<String>? onSelected,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: MasterDataSearchField<String>(
          label: 'ID Material',
          hintText: 'Cari material',
          value: '',
          prefixIcon: Icons.search,
          search: search,
          optionTitle: (option) => option,
          onSelected: (option) => onSelected?.call(option),
          onClear: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('search popup stays light when the host theme is dark',
      (tester) async {
    await tester.pumpWidget(field(
      theme: ThemeData.dark(),
      search: (_) async => ['MAT-1'],
    ));

    await tester.tap(find.text('Cari material'));
    await tester.pumpAndSettle();

    final searchContext = tester.element(
      find.byKey(const Key('master_data_search_input')),
    );
    final popupTheme = Theme.of(searchContext);
    final bottomSheet = tester.widget<BottomSheet>(find.byType(BottomSheet));

    expect(popupTheme.brightness, Brightness.light);
    expect(popupTheme.colorScheme.surface, AppColors.surface);
    expect(popupTheme.dividerColor, AppColors.borderSoft);
    expect(popupTheme.listTileTheme.textColor, AppColors.textMain);
    expect(
      popupTheme.listTileTheme.subtitleTextStyle?.color,
      AppColors.textMuted,
    );
    expect(bottomSheet.backgroundColor, AppColors.surface);
    expect(find.text('MAT-1'), findsOneWidget);
  });

  testWidgets('narrow searchable selector shows an empty-result state',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(field(search: (_) async => []));

    await tester.tap(find.text('Cari material'));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada data yang cocok.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selector error is recoverable with retry', (tester) async {
    var attempts = 0;
    String? selected;
    await tester.pumpWidget(field(
      search: (_) async {
        attempts++;
        if (attempts == 1) throw Exception('Koneksi gagal');
        return ['MAT-1'];
      },
      onSelected: (value) => selected = value,
    ));

    await tester.tap(find.text('Cari material'));
    await tester.pumpAndSettle();
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MAT-1'));
    await tester.pumpAndSettle();

    expect(selected, 'MAT-1');
  });
}
