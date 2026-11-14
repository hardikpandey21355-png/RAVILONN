import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/app_update/app_popup_dialog.dart';

Future<void> _openPopup(WidgetTester tester, String message) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AppPopupDialog(
                  title: 'Ready for your next match?',
                  message: message,
                  allowOptOut: true,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
}

void main() {
  testWidgets('messages of ten lines or fewer do not scroll', (tester) async {
    final message = List<String>.generate(
      10,
      (index) => 'Line ${index + 1}',
    ).join('\n');

    await _openPopup(tester, message);

    expect(find.text(message), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets(
    'long messages scroll without a scrollbar and hide the hint at bottom',
    (tester) async {
      final message = List<String>.generate(
        14,
        (index) => 'Line ${index + 1}',
      ).join('\n');

      await _openPopup(tester, message);

      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsOneWidget);
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await tester.drag(scrollView, const Offset(0, -1000));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    },
  );

  testWidgets('recurring popup offers an opt-out action', (tester) async {
    await _openPopup(tester, 'Join a tournament.');

    expect(find.text('Not now'), findsOneWidget);
    expect(find.text("Don't show again on this device"), findsOneWidget);
  });
}
