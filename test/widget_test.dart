import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  testWidgets('Login screen elements smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MainApp());
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
}
