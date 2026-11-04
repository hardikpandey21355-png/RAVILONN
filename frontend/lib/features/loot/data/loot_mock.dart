import '../../../core/mock/mock_data.dart';

/// One free (Sunday) loot match, exactly the fields the website's card shows.
class LootCard {
  const LootCard({
    required this.id,
    required this.mode,
    required this.team,
    required this.map,
    required this.time,
    required this.img,
    this.imageUrl = '',
    required this.prize,
    this.perKill,
    this.first,
    required this.players,
    required this.secs,
    required this.label,
    this.status = 'upcoming',
    this.roomId = '',
    this.roomPass = '',
  });

  final String id, mode, team, map, time, img, prize, players, label;
  final String imageUrl;
  final String roomId, roomPass;

  /// 'upcoming' or 'live'
  final String status;

  /// e.g. '₹5'. When set the card shows "₹5 / kill".
  final String? perKill;

  /// e.g. '₹200'. Shown as "1st Prize" only when perKill is empty.
  final String? first;

  /// Seconds left (to start for 'Starts in', to end for 'Ends in').
  final int secs;

  LootCard copyWith({String? status, String? label, int? secs}) => LootCard(
    id: id,
    mode: mode,
    team: team,
    map: map,
    time: time,
    img: img,
    imageUrl: imageUrl,
    prize: prize,
    perKill: perKill,
    first: first,
    players: players,
    secs: secs ?? this.secs,
    label: label ?? this.label,
    status: status ?? this.status,
    roomId: roomId,
    roomPass: roomPass,
  );
}

List<LootCard> lootCardsFrom(List<Tournament> tournaments) =>
    _lootCardsFrom(tournaments.where(tournamentIsLoot).toList(growable: false));

List<LootCard> _lootCardsFrom(List<Tournament> tournaments) => tournaments
    .map((tournament) {
      final details = tournament.detail.split('|');
      return LootCard(
        id: tournament.id,
        mode: tournament.mode,
        team: details.first.trim(),
        map: details.length > 1 ? details[1].trim() : '',
        time: tournament.when.split(',').last.trim(),
        img: tournament.img,
        imageUrl: tournament.bannerUrl,
        prize: tournament.prize,
        perKill: tournament.perKill,
        players: tournament.players,
        secs: tournament.secs,
        label: tournament.label,
        status: tournament.status,
        roomId: tournament.roomId,
        roomPass: tournament.roomPass,
      );
    })
    .toList(growable: false);

bool tournamentIsLoot(Tournament tournament) =>
    tournament.loot ||
    (tournament.fee.replaceAll(RegExp(r'[^0-9]'), '') == '0' &&
        tournament.perKill != null);

List<LootCard> mockLootCards() => _lootCardsFrom(MockData.lootTournaments);
bool canJoinLootToday({DateTime? now}) {
  if (MockData.forceLootOpen) return true;
  final ist = (now ?? DateTime.now()).toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  return ist.weekday == DateTime.sunday;
}

String nextLootSundayDate({DateTime? now}) {
  final ist = (now ?? DateTime.now()).toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  final daysUntilSunday =
      (DateTime.sunday - ist.weekday) % DateTime.daysPerWeek;
  final sunday = ist.add(Duration(days: daysUntilSunday));
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Sunday, ${sunday.day} ${months[sunday.month - 1]}';
}
