import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/auth/api_client.dart';
import 'package:ravilon/features/matches/data/matches_repository.dart';

class FixtureMatchesApiClient extends ApiClient {
  FixtureMatchesApiClient(this.payload);

  final Map<String, dynamic> payload;
  String? requestedPath;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requestedPath = path;
    return payload;
  }
}

void main() {
  test('loads joined match result and payout from the account API', () async {
    final api = FixtureMatchesApiClient({
      'ok': true,
      'matches': [
        {
          'id': 'match-complete-1',
          'tournamentId': 'complete-1',
          'mode': 'Evening Duo',
          'team': 'Duo',
          'map': 'Purgatory',
          'fee': 20,
          'joined': 8,
          'slots': 24,
          'perKill': 5,
          'prize': 500,
          'durationMin': 25,
          'secs': 0,
          'status': 'completed',
          'bg': 'upcoming.jpg',
          'roomId': 'room-123',
          'roomPass': 'pass-123',
          'result': {'declared': true, 'won': 350},
        },
      ],
    });

    final matches = await MatchesRepository(apiClient: api).load();

    expect(api.requestedPath, '/api/matches');
    expect(matches, hasLength(1));
    expect(matches.single.tournamentId, 'complete-1');
    expect(matches.single.startsInSecs, -1501);
    expect(matches.single.room?.roomId, 'room-123');
    expect(matches.single.result?.declared, isTrue);
    expect(matches.single.result?.won, 350);
    expect(matches.single.remote, isTrue);
  });

  test('rejects invalid match response shapes', () async {
    final repository = MatchesRepository(
      apiClient: FixtureMatchesApiClient({'ok': true, 'matches': 'invalid'}),
    );

    await expectLater(repository.load(), throwsFormatException);
  });
}
