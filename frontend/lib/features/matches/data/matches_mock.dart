/// Room ID and password shared by the admin.
class MatchRoom {
  const MatchRoom({required this.roomId, required this.roomPass});
  final String roomId;
  final String roomPass;
}

/// Result of one match for this player.
class MatchResult {
  const MatchResult({required this.declared, this.won = 0});
  final bool declared;
  final int won;
}

class MatchItem {
  const MatchItem({
    required this.id,
    required this.mode,
    required this.team,
    required this.map,
    required this.img,
    required this.prize,
    required this.fee,
    required this.joined,
    required this.slots,
    this.perKill = 0,
    required this.startsInSecs,
    this.tournamentId,
    this.mySlot,
    this.durationMin = 25,
    this.room,
    this.result,
    this.remote = false,
  });

  final String id, mode, team, map, img;
  final int prize, fee, joined, slots, perKill;

  /// Seconds from the moment the page opens. Negative = already started.
  final int startsInSecs;
  final String? tournamentId;
  final int? mySlot;
  final int durationMin;
  final MatchRoom? room;
  final MatchResult? result;
  final bool remote;

  bool get isLoot => fee == 0 && perKill > 0;
}

/// The 5 cases of the website: locked room, unlocked room, live, completed (declared), completed (pending).
List<MatchItem> mockMatches() => const [
  MatchItem(
    id: 'm1',
    tournamentId: 't2',
    mode: 'CLASH DUO',
    team: 'Duo',
    map: 'Purgatory',
    img: 'upcoming2.jpg',
    prize: 800,
    fee: 20,
    joined: 30,
    slots: 50,
    startsInSecs: 3200,
    durationMin: 25,
  ),
  MatchItem(
    id: 'm2',
    tournamentId: 't1',
    mode: 'BR SOLO',
    team: 'Solo',
    map: 'Bermuda',
    img: 'upcoming.jpg',
    prize: 500,
    fee: 10,
    joined: 48,
    slots: 100,
    perKill: 5,
    startsInSecs: 5400,
    durationMin: 25,
    room: MatchRoom(roomId: 'FF839204', roomPass: 'rs4471'),
  ),
  MatchItem(
    id: 'm3',
    tournamentId: 't3',
    mode: 'SQUAD',
    team: 'Squad',
    map: 'Kalahari',
    img: 'upcoming3.jpg',
    prize: 1500,
    fee: 40,
    joined: 60,
    slots: 100,
    perKill: 8,
    startsInSecs: 5400,
    durationMin: 25,
    room: MatchRoom(roomId: 'FF551827', roomPass: 'kal993'),
  ),
  MatchItem(
    id: 'm4',
    mode: 'SQUAD CUP',
    team: 'Squad',
    map: 'Bermuda',
    img: 'upcoming4.jpg',
    prize: 2500,
    fee: 30,
    joined: 12,
    slots: 12,
    perKill: 4,
    startsInSecs: -7200,
    durationMin: 25,
    result: MatchResult(declared: true, won: 120),
  ),
  MatchItem(
    id: 'm5',
    mode: 'BR RANKED',
    team: 'Solo',
    map: 'Alpine',
    img: 'upcoming.jpg',
    prize: 600,
    fee: 10,
    joined: 40,
    slots: 48,
    perKill: 2,
    startsInSecs: -10800,
    durationMin: 25,
    result: MatchResult(declared: false),
  ),
];
