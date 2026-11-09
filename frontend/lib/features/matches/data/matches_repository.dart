import '../../../core/auth/api_client.dart';
import 'matches_mock.dart';

class MatchesRepository {
  MatchesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<MatchItem>> load() async {
    final response = await _apiClient.getJson('/api/matches');
    final rawMatches = response['matches'];
    if (rawMatches is! List) {
      throw const FormatException('Matches response is invalid.');
    }

    return List<MatchItem>.unmodifiable(
      rawMatches.map((value) {
        if (value is! Map) {
          throw const FormatException('Matches response contains an invalid item.');
        }
        return _fromMap(Map<String, dynamic>.from(value));
      }),
    );
  }

  MatchItem _fromMap(Map<String, dynamic> item) {
    final status = item['status'];
    if (status != 'upcoming' && status != 'live' && status != 'completed') {
      throw const FormatException('Matches response contains an invalid status.');
    }

    final duration = _integer(item['durationMin']);
    final remaining = _integer(item['secs']);
    final startsIn = switch (status) {
      'upcoming' => remaining,
      'live' => -(duration * 60 - remaining).clamp(0, duration * 60),
      _ => -(duration * 60 + 1),
    };
    final rawResult = item['result'];
    final result = rawResult is Map
        ? MatchResult(
            declared: rawResult['declared'] == true,
            won: _integer(rawResult['won']),
          )
        : const MatchResult(declared: false);
    final roomId = _text(item['roomId']);
    final roomPass = _text(item['roomPass']);

    return MatchItem(
      id: _text(item['id']),
      tournamentId: _text(item['tournamentId']),
      mode: _text(item['mode'], fallback: 'Tournament'),
      team: _text(item['team'], fallback: 'Solo'),
      map: _text(item['map']),
      img: _text(item['bg'], fallback: 'upcoming.jpg'),
      prize: _integer(item['prize']),
      fee: _integer(item['fee']),
      joined: _integer(item['joined']),
      slots: _integer(item['slots']),
      mySlot: item['mySlot'] is int && (item['mySlot'] as int) > 0
          ? item['mySlot'] as int
          : null,
      perKill: _integer(item['perKill']),
      startsInSecs: startsIn,
      durationMin: duration,
      room: roomId.isNotEmpty && roomPass.isNotEmpty
          ? MatchRoom(roomId: roomId, roomPass: roomPass)
          : null,
      result: result,
      remote: true,
    );
  }

  int _integer(Object? value) {
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0) return value.round();
    return 0;
  }

  String _text(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;
}
