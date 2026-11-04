import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/features/tournaments/presentation/tournaments_page.dart';

Tournament item(String id, String status, int secs) => Tournament(
  id: id,
  game: 'Free Fire',
  mode: id,
  detail: 'Solo | Bermuda',
  status: status,
  prize: '₹500',
  fee: '₹10',
  players: '1/48',
  when: 'Today, 8:00 PM',
  secs: secs,
  label: status == 'live' ? 'Ends in' : 'Starts in',
  bg: 'upcoming.jpg',
  remote: true,
);

void main() {
  test('all lists live tournaments first and never includes completed', () {
    final items = [
      item('later-upcoming', 'upcoming', 3600),
      item('completed', 'completed', 0),
      item('live', 'live', 1200),
      item('joined-upcoming', 'upcoming', 1800),
    ];

    final all = visibleTournamentItems(
      items: items,
      tab: 'all',
      query: '',
      joined: {'joined-upcoming'},
    );
    final live = visibleTournamentItems(
      items: items,
      tab: 'live',
      query: '',
      joined: const {},
    );
    final upcoming = visibleTournamentItems(
      items: items,
      tab: 'upcoming',
      query: '',
      joined: const {},
    );

    expect(all.map((tournament) => tournament.id), [
      'live',
      'joined-upcoming',
      'later-upcoming',
    ]);
    expect(live.map((tournament) => tournament.id), ['live']);
    expect(upcoming.map((tournament) => tournament.id), [
      'joined-upcoming',
      'later-upcoming',
    ]);
  });
}
