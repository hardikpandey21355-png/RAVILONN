import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/auth/auth_session.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/features/home/presentation/home_page.dart';

void main() {
  setUp(() {
    AuthSession.gameOk.value = true;
  });

  testWidgets('empty API data does not show demo tournament cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(tournaments: <Tournament>[])),
    );
    await tester.pump();

    expect(find.text('No tournaments yet'), findsOneWidget);
    expect(find.text('₹500'), findsNothing);
    expect(find.text('₹1,000'), findsNothing);
  });

  test('countdowns longer than a day display days instead of 24+ hours', () {
    expect(rsClockWithDays(2 * 86400 + 65), '2d:00:01:05');
    expect(rsClockWithDays(23 * 3600 + 59 * 60 + 59), '23:59:59');
  });

  testWidgets('home hero updates when repository data changes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomePage(tournaments: <Tournament>[])),
    );
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          tournaments: [
            Tournament(
              id: 'admin-created',
              game: 'Free Fire',
              mode: 'Admin Event',
              detail: 'Solo | Bermuda',
              status: 'upcoming',
              prize: '₹250',
              fee: '₹10',
              players: '0/24',
              joinedCount: 2,
              playerSlots: 24,
              reservedCount: 5,
              when: 'Tomorrow',
              secs: 3600,
              label: 'Starts in',
              bg: 'main_banner.jpg',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Admin Event'), findsWidgets);
    expect(find.text('7/24'), findsWidgets);
    expect(find.text('2 real · 5 reserved'), findsNothing);
    expect(find.text('No tournaments yet'), findsNothing);
    expect(find.text('₹500'), findsNothing);
  });

  testWidgets('live tournaments replace upcoming hero slides', (tester) async {
    Tournament create(String id, String mode, String status) => Tournament(
      id: id,
      game: 'Free Fire',
      mode: mode,
      detail: 'Solo | Bermuda',
      status: status,
      prize: '₹250',
      fee: '₹10',
      players: '0/24',
      when: 'Today',
      secs: 3600,
      label: status == 'live' ? 'Ends in' : 'Starts in',
      bg: 'main_banner.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          tournaments: [
            create('live', 'Live Match', 'live'),
            create('upcoming', 'Next Match', 'upcoming'),
            create('completed', 'Finished Match', 'completed'),
          ],
        ),
      ),
    );

    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    expect(find.text('Live Match'), findsOneWidget);
    expect(find.text('Next Match'), findsWidgets);
    expect(find.text('Finished Match'), findsNothing);
  });

  testWidgets('tapping a tournament hero opens that tournament', (
    tester,
  ) async {
    String? openedTournament;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          tournaments: [
            Tournament(
              id: 'hero-tournament',
              game: 'Free Fire',
              mode: 'Featured Match',
              detail: 'Solo | Bermuda',
              status: 'upcoming',
              prize: '₹250',
              fee: '₹10',
              players: '0/24',
              when: 'Today',
              secs: 3600,
              label: 'Starts in',
              bg: 'main_banner.jpg',
            ),
          ],
          onOpenTournament: (id) => openedTournament = id,
        ),
      ),
    );

    await tester.tap(find.text('Featured Match').first);
    await tester.pump();

    expect(openedTournament, 'hero-tournament');
  });

  testWidgets('loot tournaments never appear in the home hero slider', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          tournaments: [
            Tournament(
              id: 'loot-live',
              game: 'Free Fire',
              mode: 'Loot Live Event',
              detail: 'Solo | Bermuda',
              status: 'live',
              prize: '₹500',
              fee: '₹0',
              players: '24/48',
              perKill: '₹5',
              when: 'Live now',
              secs: 3600,
              label: 'Ends in',
              bg: 'loot_banner.jpg',
              loot: true,
            ),
            Tournament(
              id: 'loot-upcoming',
              game: 'Free Fire',
              mode: 'Loot Upcoming Event',
              detail: 'Solo | Bermuda',
              status: 'upcoming',
              prize: '₹500',
              fee: '₹0',
              players: '0/48',
              perKill: '₹5',
              when: 'Sunday',
              secs: 3600,
              label: 'Starts in',
              bg: 'loot_banner.jpg',
              loot: true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Loot Live Event'), findsNothing);
    expect(find.text('Loot Upcoming Event'), findsNothing);
    expect(find.text('No tournaments yet'), findsOneWidget);
  });

  testWidgets('completed tournaments do not appear in home upcoming content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          tournaments: [
            Tournament(
              id: 'completed',
              game: 'Free Fire',
              mode: 'Finished Match',
              detail: 'Solo | Bermuda',
              status: 'completed',
              prize: '₹250',
              fee: '₹10',
              players: '24/24',
              when: 'Completed',
              secs: 0,
              label: 'Ends in',
              bg: 'main_banner.jpg',
            ),
          ],
        ),
      ),
    );

    expect(find.text('No tournaments yet'), findsOneWidget);
    expect(find.text('No upcoming tournaments'), findsOneWidget);
    expect(find.text('Finished Match'), findsNothing);
  });

  testWidgets('home refreshes tournaments when a slide timer expires', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          tournaments: [
            Tournament(
              id: 'live',
              game: 'Free Fire',
              mode: 'Live Match',
              detail: 'Solo | Bermuda',
              status: 'live',
              prize: '₹250',
              fee: '₹10',
              players: '0/24',
              when: 'Live now',
              secs: 1,
              label: 'Ends in',
              bg: 'main_banner.jpg',
            ),
          ],
          onTournamentTimerEnd: () => refreshCount++,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(refreshCount, 1);
  });
}
