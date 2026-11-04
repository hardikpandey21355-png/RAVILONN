// Dummy data for the Home page (Jinja -> mock). Image values are filenames
// relative to assets/images/.

import 'package:flutter/foundation.dart';

import '../auth/auth_session.dart';

const String kPlayerName = 'Player';

class HeroSlide {
  const HeroSlide({
    required this.tournament,
    this.live = false,
    this.game = '',
    required this.mode,
    this.prize = '',
    this.fee = '',
    this.players = '',
    this.perKill,
    this.secs = 0,
    this.label = '',
    this.line = '',
    this.bannerUrl = '',
    required this.img,
  });
  final bool tournament;
  final bool live;
  final String game;
  final String mode;
  final String prize;
  final String fee;
  final String players;
  final String? perKill;
  final int secs;
  final String label;
  final String line;
  final String bannerUrl;
  final String img;
}

class Tournament {
  const Tournament({
    required this.id,
    required this.game,
    required this.mode,
    required this.detail,
    required this.status,
    this.logo = 'ff',
    required this.prize,
    required this.fee,
    required this.players,
    this.perKill,
    required this.when,
    required this.secs,
    required this.label,
    required this.bg,
    this.bannerUrl = '',
    this.prizes = const <(String place, int amt)>[],
    this.loot = false,
    this.remote = false,
    this.roomId = '',
    this.roomPass = '',
  });
  final String id;
  final String game;
  final String mode;
  final String detail;
  final String status;
  final String logo; // 'ff' | 'cod'
  final String prize;
  final String fee;
  final String players;
  final String? perKill;
  final String when;
  final int secs;
  final String label;
  final String bg;
  final String bannerUrl;
  final List<(String place, int amt)> prizes;
  final bool loot;
  final bool remote;
  final String roomId;
  final String roomPass;
  String get img => bg;
}

class MockData {
  static final ValueNotifier<Set<String>> joinedIds =
      ValueNotifier<Set<String>>(<String>{});
  static bool forceLootOpen = false;
  static bool hasRemotePaidTournamentJoined = false;
  static final Map<String, Set<int>> takenSlotsByTournament =
      <String, Set<int>>{};

  static void clearAccountScopedState() {
    joinedIds.value = <String>{};
    hasRemotePaidTournamentJoined = false;
  }

  static ValueNotifier<int> get walletBalance => AuthSession.walletTotal;
  static ValueNotifier<bool> get gameOk => AuthSession.gameOk;
  static ValueNotifier<String> get gameIgn => AuthSession.ign;
  static ValueNotifier<String> get gameUid => AuthSession.gameUid;
  static ValueNotifier<String> get upi => AuthSession.upi;
  static ValueNotifier<bool> get hasUpi => AuthSession.hasUpi;

  static bool get hasPaidTournamentJoined =>
      hasRemotePaidTournamentJoined ||
      joinedIds.value.any(
        (id) => tournaments.any(
          (tournament) =>
              tournament.id == id &&
              (int.tryParse(tournament.fee.replaceAll(RegExp(r'[^0-9]'), '')) ??
                      0) >
                  0,
        ),
      );

  static const List<Tournament> tournaments = [
    Tournament(
      id: 't1',
      game: 'Free Fire',
      mode: 'Solo',
      detail: 'Solo | Bermuda',
      status: 'upcoming',
      prize: '₹500',
      fee: '₹10',
      players: '48/100',
      perKill: '₹5',
      when: 'Today, 8:00 PM',
      secs: 5400,
      label: 'Starts in',
      bg: 'upcoming.jpg',
    ),
    Tournament(
      id: 't2',
      game: 'Free Fire',
      mode: 'Duo',
      detail: 'Duo | Purgatory',
      status: 'upcoming',
      prize: '₹800',
      fee: '₹20',
      players: '30/50',
      when: 'Today, 9:30 PM',
      secs: 3200,
      label: 'Starts in',
      bg: 'upcoming2.jpg',
    ),
    Tournament(
      id: 't3',
      game: 'Free Fire',
      mode: 'Squad',
      detail: 'Squad | Kalahari',
      status: 'upcoming',
      prize: '₹1,500',
      fee: '₹40',
      players: '60/100',
      perKill: '₹8',
      when: 'Tomorrow, 7:00 PM',
      secs: 5400,
      label: 'Starts in',
      bg: 'upcoming3.jpg',
    ),
    Tournament(
      id: 't4',
      game: 'Free Fire',
      mode: 'Solo',
      detail: 'Solo | Bermuda',
      status: 'upcoming',
      prize: '₹300',
      fee: '₹5',
      players: '20/48',
      when: 'Tomorrow, 9:00 PM',
      secs: 8100,
      label: 'Starts in',
      bg: 'upcoming4.jpg',
    ),
    Tournament(
      id: 't5',
      game: 'Free Fire',
      mode: 'Solo',
      detail: 'Solo | Bermuda',
      status: 'live',
      prize: '₹5,000',
      fee: '₹50',
      players: '48/48',
      when: 'Live now',
      secs: 1500,
      label: 'Ends in',
      bg: 'upcoming.jpg',
    ),
    Tournament(
      id: 't6',
      game: 'Free Fire',
      mode: 'Duo',
      detail: 'Duo | Purgatory',
      status: 'upcoming',
      prize: '₹1,500',
      fee: '₹15',
      players: '4/24',
      when: 'Tomorrow, 9:00 PM',
      secs: 19800,
      label: 'Starts in',
      bg: 'upcoming2.jpg',
    ),
  ];

  static const List<Tournament> lootTournaments = [
    Tournament(
      id: 'l1',
      game: 'Free Fire',
      mode: 'Solo',
      detail: 'Solo | Bermuda',
      status: 'upcoming',
      prize: '₹500',
      fee: '₹0',
      players: '18/50',
      perKill: '₹5',
      when: 'Sunday, 6:00 PM',
      secs: 5400,
      label: 'Starts in',
      bg: 'upcoming.jpg',
    ),
    Tournament(
      id: 'l2',
      game: 'Free Fire',
      mode: 'Duo',
      detail: 'Duo | Purgatory',
      status: 'upcoming',
      prize: '₹300',
      fee: '₹0',
      players: '20/50',
      perKill: '₹3',
      when: 'Sunday, 9:00 PM',
      secs: 14400,
      label: 'Starts in',
      bg: 'upcoming2.jpg',
    ),
  ];

  static const List<Tournament> allTournaments = <Tournament>[
    ...tournaments,
    ...lootTournaments,
  ];

  static void recordTakenSlot(String tournamentId, int slot) {
    takenSlotsByTournament.putIfAbsent(tournamentId, () => <int>{}).add(slot);
  }
}

String inr(int amount) {
  final digits = amount.abs().toString();
  if (digits.length <= 3) return amount < 0 ? '-$digits' : digits;
  final leading = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  var remaining = leading;
  while (remaining.length > 2) {
    groups.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  groups.insert(0, remaining);
  final formatted =
      '${groups.join(',')},${digits.substring(digits.length - 3)}';
  return amount < 0 ? '-$formatted' : formatted;
}

/// HH{sep}MM{sep}SS, zero padded. Hero timer uses ' : '.
String rsClock(int secs, [String sep = ':']) {
  return _formatClock(secs, sep, showDays: false);
}

String rsClockWithDays(int secs) => _formatClock(secs, ':', showDays: true);

String _formatClock(int secs, String sep, {required bool showDays}) {
  final s = secs < 0 ? 0 : secs;
  String p(int n) => n.toString().padLeft(2, '0');
  final days = s ~/ 86400;
  final hours = showDays ? s % 86400 ~/ 3600 : s ~/ 3600;
  final clock = '${p(hours)}$sep${p(s % 3600 ~/ 60)}$sep${p(s % 60)}';
  return showDays && days > 0 ? '${days}d:$clock' : clock;
}
