// lib/features/tournament_detail/data/tournament_detail_mock.dart
//
// Models and mock data for the Tournament Detail / Join page (UI only).

import 'package:flutter/foundation.dart';

import '../../../core/mock/mock_data.dart';

@immutable
class TournamentDetail {
  const TournamentDetail({
    required this.id,
    required this.game,
    required this.mode,
    required this.team,
    required this.map,
    required this.img,
    required this.status,
    required this.prize,
    required this.fee,
    this.perKill,
    required this.slots,
    required this.joinedCount,
    required this.secs,
    required this.label,
    required this.when,
    this.prizes = const <(String place, int amt)>[],
    this.imageUrl = '',
    this.loot = false,
  });

  final String id;
  final String game; // 'Free Fire'
  final String mode; // 'Solo'
  final String team; // 'Squad'
  final String map; // 'Bermuda'
  final String img; // file name inside assets/images/
  final String status; // 'live' | 'upcoming'
  final int prize;
  final int fee;
  final int? perKill;
  final int slots;
  final int joinedCount;
  final int secs;
  final String label; // 'Starts in' | 'Ends in'
  final String when; // 'Today, 8:00 PM'
  final List<(String place, int amt)> prizes;
  final String imageUrl;
  final bool loot;

  bool get isLive => status == 'live';
  int get teamSize => switch (team) {
    'Duo' => 2,
    'Squad' => 4,
    _ => 1,
  };
  bool get full => joinedCount >= slots;
  bool get hasPerKill => (perKill ?? 0) > 0;

  /// Loot match theme: free entry + per-kill reward.
  bool get isLoot => loot || (fee == 0 && perKill != null);

  /// Python `|title`
  String get modeTitle {
    return mode
        .split(' ')
        .map(
          (w) =>
              w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

@immutable
class SlotsResult {
  const SlotsResult({
    required this.ok,
    this.slots = 0,
    this.taken = const <int>[],
    this.error,
  });
  final bool ok;
  final int slots;
  final List<int> taken;
  final String? error;
}

@immutable
class JoinResult {
  const JoinResult({required this.ok, this.error, this.newBalance});
  final bool ok;
  final String? error;

  /// Wallet total after joining (null => keep the current balance).
  final int? newBalance;
}

@immutable
class PayResult {
  const PayResult._({required this.ok, this.cancelled = false, this.error});

  /// Payment went through (sent for approval).
  const PayResult.success() : this._(ok: true);

  /// The user closed the payment screen (nothing is shown).
  const PayResult.cancelled() : this._(ok: false, cancelled: true);

  /// Failed. [error] is shown in the sheet (optional).
  const PayResult.failure([String? error]) : this._(ok: false, error: error);

  final bool ok;
  final bool cancelled;
  final String? error;
}

class TournamentDetailMock {
  const TournamentDetailMock._();

  static const TournamentDetail normal = TournamentDetail(
    id: 't1',
    game: 'Free Fire',
    mode: 'Squad',
    team: 'Squad',
    map: 'Bermuda',
    img: 'upcoming.jpg',
    status: 'upcoming',
    prize: 500,
    fee: 10,
    perKill: 5,
    slots: 50,
    joinedCount: 32,
    secs: 5400,
    label: 'Starts in',
    when: 'Today, 8:00 PM',
    prizes: <(String place, int amt)>[('1st', 250), ('2nd', 150), ('3rd', 100)],
  );

  /// Loot variant: fee == 0 and perKill != null.
  static const TournamentDetail loot = TournamentDetail(
    id: 't2',
    game: 'Free Fire',
    mode: 'Squad',
    team: 'Squad',
    map: 'Bermuda',
    img: 'upcoming.jpg',
    status: 'upcoming',
    prize: 500,
    fee: 0,
    perKill: 2,
    slots: 50,
    joinedCount: 32,
    secs: 5400,
    label: 'Starts in',
    when: 'Today, 8:00 PM',
    prizes: <(String place, int amt)>[('1st', 250), ('2nd', 150), ('3rd', 100)],
  );

  static const int balance = 1250;
  static const bool gameOk = true;

  static const List<int> takenSlots = <int>[
    2,
    5,
    6,
    9,
    13,
    14,
    20,
    21,
    27,
    30,
    33,
    34,
    41,
    45,
  ];

  /// Mock slots: 500 ms.
  static Future<SlotsResult> loadSlots(TournamentDetail t) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final taken = <int>{
      ...takenSlots,
      ...(MockData.takenSlotsByTournament[t.id] ?? const <int>{}),
    };
    return SlotsResult(ok: true, slots: t.slots, taken: taken.toList());
  }

  /// Mock join: 800 ms, success.
  static Future<JoinResult> join(TournamentDetail t, int balance) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return JoinResult(ok: true, newBalance: balance - t.fee);
  }

  /// Mock payment: 700 ms, success (pending approval).
  static Future<PayResult> pay(int amount) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const PayResult.success();
  }
}
