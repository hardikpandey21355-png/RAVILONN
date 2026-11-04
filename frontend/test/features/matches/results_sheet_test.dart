import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/features/matches/data/matches_mock.dart';
import 'package:ravilon/features/matches/presentation/results_sheet.dart';

void main() {
  testWidgets('pending results promise verification within 24 hours', (
    tester,
  ) async {
    final item = mockMatches().firstWhere(
      (match) => match.result?.declared == false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showResultsSheet(context, item),
              child: const Text('Open results'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open results'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text(
        'Results are being verified. Rewards can take up to 24 hours to reach your wallet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('results sheet is opaque and centers the reward', (tester) async {
    final item = mockMatches().firstWhere((match) => match.result != null);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showResultsSheet(context, item),
              child: const Text('Open results'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open results'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final sheet = tester.widget<Container>(
      find.byKey(const ValueKey<String>('match-results-sheet')),
    );
    final sheetDecoration = sheet.decoration! as BoxDecoration;
    expect(sheetDecoration.color, const Color(0xFF0A0F0E));
    expect(sheetDecoration.gradient, isNull);
    expect(sheet.child, isA<Column>());

    final prizeBox = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(const ValueKey<String>('match-result-prize-box')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final prizeDecoration = prizeBox.decoration as BoxDecoration;
    expect(prizeDecoration.color, const Color(0xFF111916));

    final prize = tester.getCenter(find.text('₹120'));
    final sheetCenter = tester.getCenter(
      find.byKey(const ValueKey<String>('match-result-prize-box')),
    );
    expect((prize.dx - sheetCenter.dx).abs(), lessThan(1));
  });
}
