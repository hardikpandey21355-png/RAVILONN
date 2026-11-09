import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/auth/api_client.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/core/widgets/wallet_chip.dart';
import 'package:ravilon/features/matches/data/matches_mock.dart';
import 'package:ravilon/features/matches/presentation/matches_page.dart';

void main() {
  setUp(() {
    MockData.joinedIds.value = <String>{'t2'};
    MockData.walletBalance.value = 1250;
  });

  tearDown(() {
    MockData.joinedIds.value = <String>{'t2'};
    MockData.walletBalance.value = 1250;
  });

  testWidgets('newly joined tournaments appear in Matches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MatchesPage(onLeave: (_) async => true)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    MockData.joinedIds.value = <String>{'t2', 't4'};
    await tester.pump();

    expect(find.text('CLASH DUO'), findsOneWidget);
    expect(find.text('Solo'), findsOneWidget);
    expect(find.textContaining('₹300'), findsOneWidget);
  });

  testWidgets('joined loot tournaments appear with golden styling', (
    tester,
  ) async {
    MockData.joinedIds.value = <String>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MatchesPage(onLeave: (_) async => true)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    MockData.joinedIds.value = <String>{'l1'};
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.byKey(const ValueKey<String>('match-card-match_l1')),
      findsOneWidget,
    );
    final card = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey<String>('match-card-match_l1')),
    );
    final decoration = card.decoration! as BoxDecoration;
    final lootBorder = (decoration.border! as Border).top.color;
    expect(lootBorder.a, closeTo(.32, .001));
    expect(lootBorder.r, closeTo(247 / 255, .001));
    expect(lootBorder.g, closeTo(215 / 255, .001));
    expect(find.text('UPCOMING'), findsOneWidget);
  });

  testWidgets('API-backed Matches contains only joined API tournaments', (
    tester,
  ) async {
    MockData.joinedIds.value = <String>{'real-tournament'};
    final tournaments = [
      const Tournament(
        id: 'real-tournament',
        game: 'Free Fire',
        mode: 'BR Solo',
        detail: 'Solo | Bermuda',
        status: 'upcoming',
        prize: '₹500',
        fee: '₹10',
        players: '1/48',
        when: 'Tomorrow, 8:00 PM',
        secs: 3600,
        label: 'Starts in',
        bg: 'upcoming.jpg',
        remote: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesPage(matches: const [], tournaments: tournaments),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey<String>('match-card-match_real-tournament')),
      findsOneWidget,
    );
    expect(find.text('CLASH DUO'), findsNothing);
  });

  testWidgets('room details appear and the leave action is removed', (
    tester,
  ) async {
    MockData.joinedIds.value = <String>{'room-ready'};
    final tournaments = [
      const Tournament(
        id: 'room-ready',
        game: 'Free Fire',
        mode: 'Room Ready Match',
        detail: 'Solo | Bermuda',
        status: 'upcoming',
        prize: '₹500',
        fee: '₹10',
        players: '1/48',
        when: 'Tomorrow, 8:00 PM',
        secs: 3600,
        label: 'Starts in',
        bg: 'upcoming.jpg',
        roomId: 'room-123',
        roomPass: 'pass-123',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesPage(matches: const [], tournaments: tournaments),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Room ID'), findsOneWidget);
    expect(find.text('room-123'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('pass-123'), findsOneWidget);
    expect(find.text('Leave Match'), findsNothing);
  });

  testWidgets('backend completed match shows its approved reward', (
    tester,
  ) async {
    final match = MatchItem(
      id: 'match-completed',
      tournamentId: 'completed-tournament',
      mode: 'Weekend Duo',
      team: 'Duo',
      map: 'Purgatory',
      img: 'upcoming.jpg',
      prize: 500,
      fee: 20,
      joined: 8,
      slots: 24,
      startsInSecs: -1501,
      result: const MatchResult(declared: true, won: 350),
      remote: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesPage(
            matches: const [],
            onLoadMatches: () async => [match],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('match-card-match-completed')),
      findsOneWidget,
    );
    expect(find.text('Results Declared'), findsOneWidget);
    await tester.tap(find.text('View Results'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('₹350'), findsOneWidget);
  });

  testWidgets('shows the backend error when matches cannot be loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesPage(
            matches: const [],
            onLoadMatches: () async {
              throw const ApiAuthException(
                message: "Can't reach the RIVALON server.",
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text("Can't reach the RIVALON server."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Browse tournaments opens the tournaments route', (tester) async {
    MockData.joinedIds.value = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: MatchesPage(
              matches: const [],
              onBrowseTournaments: () => Navigator.of(
                context,
                rootNavigator: true,
              ).pushNamed('/tournaments'),
            ),
          ),
        ),
        routes: {
          '/tournaments': (_) =>
              const Scaffold(body: Text('Tournament list destination')),
        },
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Browse tournaments'));
    await tester.tap(find.text('Browse tournaments'));
    await tester.pumpAndSettle();

    expect(find.text('Tournament list destination'), findsOneWidget);
  });

  testWidgets('leaving a joined match updates shared join and wallet state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchesPage(
            walletChip: WalletChip(balanceListenable: MockData.walletBalance),
            onLeave: (_) async => true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('CLASH DUO'), findsOneWidget);
    expect(find.text('BR SOLO'), findsNothing);
    await tester.ensureVisible(find.text('Leave Match'));
    await tester.tap(find.text('Leave Match'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Leave').last);
    await tester.pump();

    expect(MockData.joinedIds.value, isNot(contains('t2')));
    expect(MockData.walletBalance.value, 1270);
    await tester.pump(const Duration(milliseconds: 400));
  });
}
