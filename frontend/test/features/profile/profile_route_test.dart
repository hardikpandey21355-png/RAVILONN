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
}
