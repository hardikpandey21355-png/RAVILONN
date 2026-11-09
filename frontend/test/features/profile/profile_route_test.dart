import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/main.dart';

void main() {
  testWidgets('Profile navigation opens the integrated profile page', (
    tester,
  ) async {
    MockData.gameOk.value = false;
    MockData.gameIgn.value = '';
    MockData.gameUid.value = '';
    MockData.upi.value = '';
    MockData.hasUpi.value = false;

    await tester.pumpWidget(const RivalonApp(initialRoute: '/profile'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Manage • Verify • Play'), findsOneWidget);
  });

  testWidgets('logout confirmation uses the Rivalon brand', (tester) async {
    await tester.pumpWidget(const RivalonApp(initialRoute: '/profile'));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.ensureVisible(find.text('Log out'));
    await tester.pump();
    await tester.tap(find.text('Log out'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Log out of Rivalon?'), findsOneWidget);
    expect(find.text('Log out of RudelySmash?'), findsNothing);
  });
}
