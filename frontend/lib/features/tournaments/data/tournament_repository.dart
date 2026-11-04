import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/auth/api_client.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/mock/mock_data.dart';
import '../../tournament_detail/data/tournament_detail_mock.dart';

class TournamentRepository extends WidgetsBindingObserver {
  TournamentRepository({
    ApiClient? apiClient,
    List<Tournament>? mockItems,
    this.refreshInterval = const Duration(seconds: 30),
  }) : _apiClient = apiClient ?? ApiClient(),
       _mockItems = mockItems,
       _cached = List<Tournament>.unmodifiable(
         mockItems ?? const <Tournament>[],
       ),
       _observedUserId = AuthSession.userId.value,
       tournaments = ValueNotifier<List<Tournament>>(
         List<Tournament>.unmodifiable(mockItems ?? const <Tournament>[]),
       ) {
    AuthSession.userId.addListener(_onUserChanged);
  }

  static final TournamentRepository shared = TournamentRepository();

  final ApiClient _apiClient;
  final List<Tournament>? _mockItems;
  final Duration refreshInterval;
  final ValueNotifier<List<Tournament>> tournaments;
  List<Tournament> _cached;
  String _observedUserId;
  Future<List<Tournament>>? _inFlight;
  Timer? _refreshTimer;
  bool _observerRegistered = false;
  int _requestGeneration = 0;

  List<Tournament> get cached => _cached;
  bool hasLoaded = false;
  Object? loadError;

  Tournament? find(String id) {
    for (final tournament in _cached) {
      if (tournament.id == id) return tournament;
    }
    return null;
  }

  Future<List<Tournament>> load({bool force = false}) {
    if (_mockItems != null) {
      _cached = List<Tournament>.unmodifiable(_mockItems);
      hasLoaded = true;
      return Future<List<Tournament>>.value(_cached);
    }
    _startRefreshLoop();
    if (_inFlight != null) return _inFlight!;
    if (!force && hasLoaded) return Future<List<Tournament>>.value(_cached);

    final request = _fetch();
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<List<Tournament>> refresh() => load(force: true);

  Future<List<Tournament>> _fetch() async {
    final requestUid = _observedUserId;
    final requestGeneration = _requestGeneration;
    try {
      final response = await _apiClient.getJson('/api/tournaments');
      if (!_isCurrentRequest(requestUid, requestGeneration)) return _cached;
      final raw = response['tournaments'];
      if (raw is! List) {
        throw const FormatException('Tournament response is invalid.');
      }
      final loaded = <Tournament>[];
      for (final item in raw) {
        if (item is! Map) {
          throw const FormatException(
            'Tournament response contains an invalid item.',
          );
        }
        loaded.add(_fromMap(Map<String, dynamic>.from(item)));
      }
      MockData.joinedIds.value = {
        for (final item in raw)
          if (item is Map && item['joinedByMe'] == true && item['id'] is String)
            item['id'] as String,
      };
      MockData.hasRemotePaidTournamentJoined = raw.any(
        (item) =>
            item is Map &&
            item['joinedByMe'] == true &&
            _integer(item['fee']) > 0,
      );
      final wallet = _asMap(response['wallet']);
      if (wallet.isNotEmpty) {
        AuthSession.deposited.value = _integer(wallet['deposited']);
        AuthSession.bonus.value = _integer(wallet['bonus']);
        AuthSession.winnings.value = _integer(wallet['winnings']);
        AuthSession.walletTotal.value = _integer(wallet['total']);
      }
      _cached = List<Tournament>.unmodifiable(loaded);
      tournaments.value = _cached;
      loadError = null;
      hasLoaded = true;
      return _cached;
    } catch (error) {
      if (_isCurrentRequest(requestUid, requestGeneration)) {
        loadError = error;
        if (!hasLoaded) {
          hasLoaded = true;
          tournaments.value = List<Tournament>.unmodifiable(_cached);
        }
      }
      rethrow;
    }
  }

  Future<SlotsResult> loadSlots(String tournamentId) async {
    if (_mockItems != null) {
      final tournament = find(tournamentId);
      if (tournament == null) return const SlotsResult(ok: false);
      return TournamentDetailMock.loadSlots(_mockDetail(tournament));
    }
    final requestUid = _observedUserId;
    final requestGeneration = _requestGeneration;
    try {
      final response = await _apiClient.getJson(
        '/api/tournaments/$tournamentId/slots',
      );
      if (!_isCurrentRequest(requestUid, requestGeneration)) {
        return const SlotsResult(
          ok: false,
          error: 'Your session changed. Please try again.',
        );
      }
      final rawTaken = response['taken'];
      if (response['slots'] is! int || rawTaken is! List) {
        throw const FormatException('Tournament slots response is invalid.');
      }
      final taken = <int>[];
      for (final slot in rawTaken) {
        if (slot is! int) {
          throw const FormatException('Tournament slot response is invalid.');
        }
        taken.add(slot);
      }
      return SlotsResult(
        ok: true,
        slots: response['slots'] as int,
        taken: taken,
      );
    } on ApiAuthException catch (error) {
      return SlotsResult(ok: false, error: error.message);
    }
  }

  Future<JoinResult> join(String tournamentId, int slot) async {
    final requestUid = _observedUserId;
    final requestGeneration = _requestGeneration;
    if (_mockItems != null) {
      final tournament = find(tournamentId);
      if (tournament == null) {
        return const JoinResult(ok: false, error: 'Tournament was not found.');
      }
      final result = await TournamentDetailMock.join(
        _mockDetail(tournament),
        AuthSession.walletTotal.value,
      );
      if (!result.ok) return result;
      if (!_isCurrentRequest(requestUid, requestGeneration)) {
        return const JoinResult(
          ok: false,
          error: 'Your session changed. Please try again.',
        );
      }
      final total = result.newBalance ?? AuthSession.walletTotal.value;
      AuthSession.walletTotal.value = total;
      MockData.joinedIds.value = {...MockData.joinedIds.value, tournamentId};
      MockData.recordTakenSlot(tournamentId, slot);
      return JoinResult(ok: true, newBalance: total);
    }
    try {
      final response = await _apiClient.postJson(
        '/api/tournaments/$tournamentId/join',
        body: {'slot': slot},
      );
      if (!_isCurrentRequest(requestUid, requestGeneration)) {
        return const JoinResult(
          ok: false,
          error: 'Your session changed. Please try again.',
        );
      }
      final wallet = _asMap(response['wallet']);
      final total = _integer(wallet['total']);
      AuthSession.walletTotal.value = total;
      AuthSession.deposited.value = _integer(wallet['deposited']);
      AuthSession.bonus.value = _integer(wallet['bonus']);
      AuthSession.winnings.value = _integer(wallet['winnings']);
      MockData.joinedIds.value = {...MockData.joinedIds.value, tournamentId};
      MockData.recordTakenSlot(tournamentId, slot);
      unawaited(refresh().catchError((Object _) => _cached));
      return JoinResult(ok: true, newBalance: total);
    } on ApiAuthException catch (error) {
      return JoinResult(ok: false, error: error.message);
    }
  }

  void _startRefreshLoop() {
    if (_observerRegistered || refreshInterval <= Duration.zero) return;
    WidgetsBinding.instance.addObserver(this);
    _observerRegistered = true;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (refreshInterval <= Duration.zero) return;
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(refresh().catchError((Object _) => _cached));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh().catchError((Object _) => _cached));
      _scheduleRefresh();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _observerRegistered = false;
    }
  }

  void dispose() {
    stopPolling();
    AuthSession.userId.removeListener(_onUserChanged);
    tournaments.dispose();
  }

  void _onUserChanged() {
    final userId = AuthSession.userId.value;
    if (_observedUserId == userId) return;

    _observedUserId = userId;
    _requestGeneration++;
    _inFlight = null;
    _cached = List<Tournament>.unmodifiable(
      _mockItems ?? const <Tournament>[],
    );
    tournaments.value = _cached;
    MockData.clearAccountScopedState();
    hasLoaded = _mockItems != null;
    loadError = null;
  }

  bool _isCurrentRequest(String userId, int generation) =>
      userId == _observedUserId &&
      userId == AuthSession.userId.value &&
      generation == _requestGeneration;

  Tournament _fromMap(Map<String, dynamic> item) {
    final mode = _text(item['mode'], 'Tournament');
    final team = _text(item['team'], 'Solo');
    final map = _text(item['map'], '');
    final fee = _integer(item['fee']);
    final perKill = _integer(item['per_kill'] ?? item['perKill']);
    final prizes = item['prizes'];
    return Tournament(
      id: _text(item['id'], ''),
      game: _text(item['game'], 'Free Fire'),
      mode: mode,
      detail: '$team | $map',
      status: _text(item['status'], 'upcoming'),
      logo: 'ff',
      prize: '₹${inr(_integer(item['prize']))}',
      fee: '₹${inr(fee)}',
      players: '${_integer(item['joined'])}/${_integer(item['slots'])}',
      perKill: perKill > 0 ? '₹${inr(perKill)}' : null,
      when: _text(item['when'], ''),
      secs: _integer(item['secs']),
      label: _text(item['label'], 'Starts in'),
      bg: _text(item['bg'] ?? item['banner'], 'upcoming.jpg'),
      bannerUrl: _text(item['bannerUrl'], ''),
      prizes: _prizeList(prizes),
      loot: item['loot'] == true,
      remote: true,
      roomId: _text(item['roomId'] ?? item['room_id'], ''),
      roomPass: _text(item['roomPass'] ?? item['room_pass'], ''),
    );
  }

  List<(String, int)> _prizeList(dynamic value) {
    if (value is! List) return const <(String, int)>[];
    return List<(String, int)>.generate(value.length, (index) {
      final place = switch (index + 1) {
        1 => '1st',
        2 => '2nd',
        3 => '3rd',
        final number => '${number}th',
      };
      return (place, _integer(value[index]));
    }, growable: false);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  TournamentDetail _mockDetail(Tournament tournament) {
    final defaults = TournamentDetailMock.normal;
    final details = tournament.detail
        .split('|')
        .map((part) => part.trim())
        .toList(growable: false);
    final counts = tournament.players.split('/');
    int number(String value) =>
        int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    return TournamentDetail(
      id: tournament.id,
      game: tournament.game,
      mode: tournament.mode,
      team: details.isNotEmpty && details.first.isNotEmpty
          ? details.first
          : defaults.team,
      map: details.length > 1 ? details[1] : defaults.map,
      img: tournament.img,
      status: tournament.status,
      prize: number(tournament.prize),
      fee: number(tournament.fee),
      perKill: tournament.perKill == null ? null : number(tournament.perKill!),
      slots: counts.length > 1 ? number(counts.last) : defaults.slots,
      joinedCount: counts.isEmpty ? defaults.joinedCount : number(counts.first),
      secs: tournament.secs,
      label: tournament.label,
      when: tournament.when,
      prizes: tournament.prizes,
      imageUrl: tournament.bannerUrl,
      loot: tournament.loot,
    );
  }

  int _integer(dynamic value) {
    if (value is int && value >= 0) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _text(dynamic value, String fallback) =>
      value is String ? value : fallback;
}
