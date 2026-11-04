import 'package:flutter_test/flutter_test.dart';

import 'package:ravilon/core/auth/auth_session.dart';
import 'package:ravilon/main.dart';

void main() {
  testWidgets('shows the login screen', (tester) async {
    await tester.pumpWidget(const RivalonApp(initialRoute: '/login'));

    expect(find.text('RIVALON'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('login and signup watermark stays behind the brand', (
    tester,
  ) async {
    await tester.pumpWidget(const RivalonApp(initialRoute: '/login'));
    await tester.pump(const Duration(seconds: 2));

    void expectWatermarkAligned(String label) {
      final watermark = tester.getRect(find.text(label));
      final brand = tester.getRect(find.text('RIVALON'));
      expect((watermark.center.dy - brand.center.dy).abs(), lessThan(1));
    }

    expectWatermarkAligned('LOGIN');
    await tester.tap(find.text('Sign up'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('JOIN'), findsOneWidget);
    expectWatermarkAligned('JOIN');
  });

  testWidgets('account hold screen opens the legal contact page', (
    tester,
  ) async {
    AuthSession.accountHeld.value = false;
    AuthSession.maintenanceOn.value = false;
    await tester.pumpWidget(const RivalonApp(initialRoute: '/held'));
    await tester.pump();

    await tester.tap(find.text('Contact us for help or support'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Contact Us'), findsOneWidget);
  });

  testWidgets('maintenance screen opens the legal contact page', (
    tester,
  ) async {
    AuthSession.accountHeld.value = false;
    AuthSession.maintenanceOn.value = true;
    addTearDown(() => AuthSession.maintenanceOn.value = false);
    await tester.pumpWidget(const RivalonApp(initialRoute: '/held'));
    await tester.pump();

    await tester.tap(
      find.descendant(
        of: find.byType(MaintenancePage),
        matching: find.text('Contact us for help or support'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Contact Us'), findsOneWidget);
  });
}
