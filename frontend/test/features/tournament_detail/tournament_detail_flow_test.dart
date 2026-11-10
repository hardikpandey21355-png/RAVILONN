import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/features/tournament_detail/presentation/tournament_detail_page.dart';
import 'package:ravilon/features/tournaments/data/tournament_repository.dart';
import 'package:ravilon/main.dart';

void main() {
  testWidgets('joining a tournament stays on its detail page', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MockData.walletBalance.value = 1250;
    MockData.gameOk.value = true;
    MockData.joinedIds.value = <String>{'t2'};
    MockData.takenSlotsByTournament.clear();

    await tester.pumpWidget(
      RivalonApp(
        initialRoute: '/tournament/t1',
        tournamentRepository: TournamentRepository(
          mockItems: MockData.allTournaments,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Join Now • ₹10'), findsOneWidget);

    await tester.tap(find.text('Join Now • ₹10'));
    await tester.pumpAndSettle();
    expect(tester.state<JoinSheetState>(find.byType(JoinSheet)).isOpen, isTrue);
    final slotOne = find.descendant(
      of: find.byType(SlotGrid),
      matching: find.text('1'),
    );
    await tester.tap(slotOne);
    await tester.pumpAndSettle();
    expect(tester.state<JoinSheetState>(find.byType(JoinSheet)).isOpen, isTrue);
    final confirm = find.text('Confirm Slot 1 • ₹10');
    final cancel = find.text('Cancel');
    expect(confirm, findsOneWidget);
    expect(cancel, findsOneWidget);
    final actionBottom = tester.getRect(cancel).bottom;
    expect(actionBottom, lessThanOrEqualTo(tester.view.physicalSize.height /
        tester.view.devicePixelRatio));
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 900));

    expect(MockData.walletBalance.value, 1240);
    expect(MockData.joinedIds.value, contains('t1'));
    expect(MockData.takenSlotsByTournament['t1'], contains(1));
    expect(find.text('Joined ✓'), findsOneWidget);
    expect(find.text('₹ 1,240'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Joined • View in My Matches'), findsOneWidget);
  });

  testWidgets('joining a loot tournament stays on its detail page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    MockData.walletBalance.value = 1250;
    MockData.gameOk.value = true;
    MockData.joinedIds.value = <String>{};
    MockData.takenSlotsByTournament.clear();

    await tester.pumpWidget(
      RivalonApp(
        initialRoute: '/tournament/l1',
        tournamentRepository: TournamentRepository(
          mockItems: MockData.allTournaments,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Join Now • ₹0'), findsOneWidget);

    await tester.tap(find.text('Join Now • ₹0'));
    await tester.pumpAndSettle();
    final slotOne = find.descendant(
      of: find.byType(SlotGrid),
      matching: find.text('1'),
    );
    await tester.tap(slotOne);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Slot 1 • ₹0'));
    await tester.pump(const Duration(milliseconds: 900));

    expect(MockData.joinedIds.value, contains('l1'));
    expect(find.text('Joined ✓'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Joined • View in My Matches'), findsOneWidget);
  });
}
