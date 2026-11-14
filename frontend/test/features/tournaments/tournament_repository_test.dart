import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ravilon/core/auth/api_client.dart';
import 'package:ravilon/core/auth/auth_session.dart';
import 'package:ravilon/core/mock/mock_data.dart';
import 'package:ravilon/features/tournaments/data/tournament_repository.dart';

class FixtureApiClient extends ApiClient {
  FixtureApiClient(this.payload, {this.slotPayload, this.joinPayload});

  Map<String, dynamic> payload;
  final Map<String, dynamic>? slotPayload;
  final Map<String, dynamic>? joinPayload;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path == '/api/tournaments') return payload;
    if (path.endsWith('/slots')) return slotPayload!;
    fail('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    expect(path, '/api/tournaments/tournament-1/join');
    expect(body, {'slot': 3});
    payload['wallet'] = joinPayload!['wallet'];
    return joinPayload!;
  }
}

class SwitchingApiClient extends ApiClient {
  final Completer<Map<String, dynamic>> firstResponse =
      Completer<Map<String, dynamic>>();
  Map<String, dynamic> secondResponse = const <String, dynamic>{};
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    expect(path, '/api/tournaments');
    calls++;
    return calls == 1
        ? firstResponse.future
        : Future<Map<String, dynamic>>.value(secondResponse);
  }
}

void main() {
  test('loads and maps Firestore tournament records for the APK', () async {
    final repository = TournamentRepository(
      refreshInterval: Duration.zero,
      apiClient: FixtureApiClient({
        'ok': true,
        'tournaments': [
          {
            'id': 'admin-created',
            'game': 'Free Fire',
            'mode': 'Weekend Solo',
            'team': 'Solo',
            'map': 'Bermuda',
            'fee': 25,
            'prize': 500,
            'joined': 2,
            'slots': 48,
            'playerSlots': 48,
            'reservedCount': 5,
            'players': '2/48',
            'perKill': 10,
            'status': 'upcoming',
            'when': 'Tomorrow, 8:00 PM',
            'secs': 3600,
            'label': 'Starts in',
            'bg': 'upcoming.jpg',
            'bannerUrl': '',
            'prizes': [300, 200],
            'loot': false,
            'joinedByMe': true,
            'roomId': 'room-123',
            'roomPass': 'pass-123',
          },
        ],
      }),
    );

    final items = await repository.load();

    expect(items, hasLength(1));
    expect(items.single.id, 'admin-created');
    expect(items.single.fee, '₹25');
    expect(items.single.players, '2/48');
    expect(items.single.joinedCount, 2);
    expect(items.single.playerSlots, 48);
    expect(items.single.bookedPlayers, '7/48');
    expect(items.single.roomId, 'room-123');
    expect(items.single.roomPass, 'pass-123');
    expect(items.single.prizes, [('1st', 300), ('2nd', 200)]);
    expect(repository.find('admin-created'), same(items.single));
    repository.dispose();
  });

  test(
    'does not silently substitute mock records on an invalid API shape',
    () async {
      final repository = TournamentRepository(
        refreshInterval: Duration.zero,
        apiClient: FixtureApiClient({'ok': true, 'tournaments': 'invalid'}),
      );
      await expectLater(repository.load(), throwsFormatException);
      repository.dispose();
    },
  );

  test('publishes empty API data and replaces it on refresh', () async {
    final api = FixtureApiClient({'ok': true, 'tournaments': <Object>[]});
    final repository = TournamentRepository(
      apiClient: api,
      refreshInterval: Duration.zero,
    );
    var updates = 0;
    repository.tournaments.addListener(() => updates++);

    expect(await repository.load(), isEmpty);
    expect(repository.tournaments.value, isEmpty);

    api.payload = {
      'ok': true,
      'tournaments': [
        {
          'id': 'new-admin-tournament',
          'game': 'Free Fire',
          'mode': 'Solo',
          'team': 'Solo',
          'map': 'Bermuda',
          'fee': 10,
          'prize': 250,
          'joined': 0,
          'slots': 24,
          'status': 'upcoming',
        },
      ],
    };

    await repository.refresh();

    expect(repository.tournaments.value.single.id, 'new-admin-tournament');
    expect(updates, 2);
    repository.dispose();
  });

  test(
    'account switches clear cached memberships and ignore stale responses',
    () async {
      AuthSession.clear();
      final api = SwitchingApiClient();
      final repository = TournamentRepository(
        apiClient: api,
        refreshInterval: Duration.zero,
      );
      addTearDown(repository.dispose);
      addTearDown(AuthSession.clear);

      AuthSession.userId.value = 'first-account';
      final firstLoad = repository.load();

      api.secondResponse = {
        'ok': true,
        'tournaments': [
          {
            'id': 'shared-tournament',
            'game': 'Free Fire',
            'mode': 'Solo',
            'team': 'Solo',
            'map': 'Bermuda',
            'fee': 25,
            'prize': 500,
            'joined': 1,
            'slots': 48,
            'status': 'upcoming',
            'joinedByMe': false,
          },
        ],
      };
      AuthSession.userId.value = 'second-account';

      expect(repository.cached, isEmpty);
      expect(MockData.joinedIds.value, isEmpty);
      expect(MockData.hasRemotePaidTournamentJoined, isFalse);

      final secondItems = await repository.load();
      api.firstResponse.complete({
        'ok': true,
        'tournaments': [
          {
            'id': 'shared-tournament',
            'game': 'Free Fire',
            'mode': 'Solo',
            'team': 'Solo',
            'map': 'Bermuda',
            'fee': 25,
            'prize': 500,
            'joined': 1,
            'slots': 48,
            'status': 'upcoming',
            'joinedByMe': true,
            'roomId': 'private-room',
            'roomPass': 'private-pass',
          },
        ],
      });
      await firstLoad;

      expect(secondItems, hasLength(1));
      expect(repository.cached.single.roomId, isEmpty);
      expect(repository.cached.single.roomPass, isEmpty);
      expect(MockData.joinedIds.value, isEmpty);
      expect(repository.hasLoaded, isTrue);
    },
  );

  test(
    'loads occupied slots and joins through the authenticated API',
    () async {
      final api = FixtureApiClient(
        {
          'ok': true,
          'wallet': {
            'deposited': 80,
            'bonus': 10,
            'winnings': 10,
            'total': 100,
          },
          'tournaments': [
            {
              'id': 'tournament-1',
              'game': 'Free Fire',
              'mode': 'Solo',
              'team': 'Solo',
              'map': 'Bermuda',
              'fee': 10,
              'prize': 100,
              'joined': 1,
              'slots': 10,
              'status': 'upcoming',
              'joinedByMe': true,
            },
          ],
        },
        slotPayload: {
          'ok': true,
          'slots': 10,
          'taken': [1, 2],
        },
        joinPayload: {
          'ok': true,
          'joined': true,
          'slot': 3,
          'wallet': {'deposited': 70, 'bonus': 10, 'winnings': 10, 'total': 90},
        },
      );
      final repository = TournamentRepository(
        apiClient: api,
        refreshInterval: Duration.zero,
      );
      AuthSession.walletTotal.value = 100;

      final slots = await repository.loadSlots('tournament-1');
      expect(slots.ok, isTrue);
      expect(slots.taken, [1, 2]);

      final result = await repository.join('tournament-1', 3);
      await repository.refresh();

      expect(result.ok, isTrue);
      expect(result.newBalance, 90);
      expect(AuthSession.walletTotal.value, 90);
      expect(MockData.joinedIds.value, contains('tournament-1'));
      expect(MockData.takenSlotsByTournament['tournament-1'], contains(3));
      repository.dispose();
    },
  );
}
