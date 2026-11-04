import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/core/rs_kit.dart';
import 'package:ravilon/features/loot/data/loot_mock.dart';
import 'package:ravilon/features/loot/presentation/loot_match_card.dart';
import 'package:ravilon/features/matches/presentation/matches_page.dart';
import 'package:ravilon/features/tournament_detail/presentation/tournament_detail_page.dart';
import 'package:ravilon/features/tournaments/data/tournament_repository.dart';
import 'package:ravilon/main.dart';

void main() {
  setUp(() {
    MockData.forceLootOpen = true;
    MockData.joinedIds.value = <String>{'t2'};
  });

  tearDown(() {
    MockData.forceLootOpen = false;
    MockData.joinedIds.value = <String>{'t2'};
    MockData.takenSlotsByTournament.clear();
  });

  test('loot availability and Sunday date use India Standard Time', () {
    MockData.forceLootOpen = false;
    expect(canJoinLootToday(now: DateTime.utc(2026, 10, 31, 20)), isTrue);
    expect(canJoinLootToday(now: DateTime.utc(2026, 11, 1, 10)), isTrue);
    expect(canJoinLootToday(now: DateTime.utc(2026, 11, 2, 0)), isFalse);
    expect(
      nextLootSundayDate(now: DateTime.utc(2026, 10, 31, 18)),
      'Sunday, 1 Nov',
    );

    MockData.forceLootOpen = true;
    expect(canJoinLootToday(now: DateTime.utc(2026, 11, 2, 0)), isTrue);
  });

  testWidgets('loot card opens its shared tournament detail route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2160, 3900);
    tester.view.devicePixelRatio = 2.7;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final card = mockLootCards().first;
    expect(card.id, 'l1');
    expect(
      MockData.allTournaments
          .singleWhere((tournament) => tournament.id == card.id)
          .fee,
      '₹0',
    );

    await tester.pumpWidget(
      RivalonApp(
        initialRoute: '/loot',
        tournamentRepository: TournamentRepository(
          mockItems: MockData.allTournaments,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(MockData.hasPaidTournamentJoined, isTrue);
    expect(find.text('LOOT\nTOURNAMENTS'), findsOneWidget);
    final lootCard = tester.widget<LootMatchCard>(
      find.byType(LootMatchCard).first,
    );
    expect(lootCard.canJoin, isTrue);
    expect(lootCard.paidOk, isTrue);
    expect(lootCard.onOpen, isNotNull);
    final joinFree = find.text('Join Free').first;
    await tester.ensureVisible(joinFree);
    final joinButton = find
        .ancestor(of: joinFree, matching: find.byType(RsPress))
        .first;
    await tester.tap(joinButton);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Details'), findsOneWidget);

    final detail = tester.widget<TournamentDetailPage>(
      find.byType(TournamentDetailPage),
    );
    expect(detail.tournament.id, 'l1');
    expect(detail.tournament.isLoot, isTrue);

    Navigator.of(tester.element(find.byType(TournamentDetailPage))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    MockData.joinedIds.value = <String>{'t2', 'l1'};
    await tester.pump();
    expect(find.text('Joined'), findsOneWidget);
  });

  testWidgets('joined loot tournaments appear in Matches', (tester) async {
    MockData.joinedIds.value = <String>{'l1'};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MatchesPage())));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MatchesPage), findsOneWidget);
    expect(find.text('FREE FIRE • Solo | Bermuda'), findsOneWidget);
  });

  testWidgets('joined loot banner shows its room details only to its player', (
    tester,
  ) async {
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    const card = LootCard(
      id: 'loot-room',
      mode: 'Solo',
      team: 'Solo',
      map: 'Bermuda',
      time: '8:00 PM',
      img: 'loot_banner.jpg',
      prize: '₹500',
      players: '1/48',
      secs: 3600,
      label: 'Starts in',
      roomId: 'loot-room-123',
      roomPass: 'loot-pass-123',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LootMatchCard(
            card: card,
            tick: tick,
            canJoin: true,
            paidOk: true,
            joined: true,
          ),
        ),
      ),
    );

    expect(find.text('ROOM ID'), findsOneWidget);
    expect(find.text('loot-room-123'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('loot-pass-123'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LootMatchCard(
            card: card,
            tick: tick,
            canJoin: true,
            paidOk: true,
            joined: false,
          ),
        ),
      ),
    );

    expect(find.text('loot-room-123'), findsNothing);
    expect(find.text('loot-pass-123'), findsNothing);
  });
}
