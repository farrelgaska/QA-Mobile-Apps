import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('Login screen elements smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the login screen is rendered
    expect(find.text('QA Mobile Apps'), findsOneWidget);
    expect(find.text('Masuk dengan akun SSO'), findsOneWidget);

    // Verify form input elements exist
    expect(find.text('NIK / Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify the Login button is rendered
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets(
    'Login actions remain usable without overflow at narrow viewports',
    (tester) async {
      for (final width in <double>[320, 360, 375, 392]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(
          MaterialApp(home: LoginScreen(key: ValueKey(width))),
        );
        await tester.pump();

        expect(find.byKey(const Key('login-actions-narrow')), findsOneWidget);
        expect(find.text('Ingat Saya'), findsOneWidget);
        expect(find.text('Lupa Password?'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport $width');

        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

        await tester.tap(find.byKey(const Key('forgot-password-action')));
        await tester.pump();
        expect(find.textContaining('hubungi IT Support'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'viewport $width');
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
