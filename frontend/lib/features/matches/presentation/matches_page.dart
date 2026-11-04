import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/auth/api_client.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/rs_kit.dart';
import '../../../core/widgets/wallet_chip.dart';
import '../data/matches_mock.dart';
import 'match_card.dart';
import 'matches_empty_state.dart';

TextStyle _t(
  double size,
  FontWeight w,
  Color color, {
  double ls = 0,
  double? h,
}) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: w,
  color: color,
  letterSpacing: ls,
  height: h,
);
Duration _d(BuildContext c, int ms) => MediaQuery.disableAnimationsOf(c)
    ? Duration.zero
    : Duration(milliseconds: ms);

const String _pClock =
    r'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
const String _pCheck = r'<path d="M5 12l5 5 9-10"/>';

/// Every block rises (opacity 0->1, 18px up, 600ms) after its own delay, like the website's "rise" animation.
class _Rise extends StatefulWidget {
  const _Rise({super.key, required this.delayMs, required this.child});
  final int delayMs;
  final Widget child;
  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.value = 1;
    } else {
      _timer = Timer(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _ctl.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctl,
    child: widget.child,
    builder: (_, c) {
      final e = kRsEase.transform(_ctl.value);
      return Opacity(
        opacity: e,
        child: Transform.translate(offset: Offset(0, 18 * (1 - e)), child: c),
      );
    },
  );
}

// ===================================================================== PAGE
class MatchesPage extends StatefulWidget {
  const MatchesPage({
    super.key,
    this.walletChip,
    this.onBrowseTournaments,
    this.onLeave,
    this.onCopy,
    this.onLoadMatches,
    this.matches,
    this.tournaments,
    this.bottomInset = const EdgeInsets.only(bottom: 100),
    this.imageBase = 'assets/images/',
  });

  /// Header right side. Default is a simple "₹ 1,250" pill.
  final Widget? walletChip;

  /// Button of the empty state ("Browse tournaments").
  final VoidCallback? onBrowseTournaments;

  /// Called after the player confirms "Leave Match". Return true to remove the card.
  final Future<bool> Function(String id)? onLeave;

  /// Copy of Room ID / password. Default: Clipboard.
  final Future<void> Function(String roomIdOrPass)? onCopy;

  /// Loads this account's joined matches from the backend.
  final Future<List<MatchItem>> Function()? onLoadMatches;

  /// null = mock data.
  final List<MatchItem>? matches;
  final List<Tournament>? tournaments;

  /// Extra padding at the bottom (space for the bottom nav).
  final EdgeInsets bottomInset;

  /// 'assets/images/' (asset files) or 'https://.../static/images/' (network).
  final String imageBase;

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  late final DateTime _base = DateTime.now();
  late List<MatchItem> _items;
  final Set<String> _leaving = <String>{};
  final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(DateTime.now());
  Timer? _timer;
  Timer? _refreshTimer;
  String _tab = 'upcoming';
  String _sig = '';
  bool _loadingMatches = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _items = _initialItems();
    MockData.joinedIds.addListener(_onJoinedIdsChanged);
    if (widget.onLoadMatches != null) {
      _loadMatches();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadMatches(),
      );
    }
    _sig = _signature(DateTime.now());
    // every second only the timer texts update; the list is rebuilt only when something really changes
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      _now.value = n;
      final s = _signature(n);
      if (s != _sig) {
        _sig = s;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(MatchesPage old) {
    super.didUpdateWidget(old);
    if (!identical(old.matches, widget.matches) ||
        !identical(old.tournaments, widget.tournaments) ||
        !identical(old.onLoadMatches, widget.onLoadMatches)) {
      if (widget.onLoadMatches != null) {
        _loadMatches();
      } else {
        _items = _initialItems();
        _sig = _signature(DateTime.now());
      }
    }
  }

  List<MatchItem> _initialItems() {
    if (widget.onLoadMatches != null) {
      return List<MatchItem>.of(widget.matches ?? const <MatchItem>[]);
    }
    final items = List<MatchItem>.of(
      widget.matches ??
          (widget.tournaments == null ? mockMatches() : const <MatchItem>[]),
    );
    _addJoinedTournamentItems(items);
    return items;
  }

  void _addJoinedTournamentItems(List<MatchItem> items) {
    if (widget.onLoadMatches != null) return;
    for (final tournament in widget.tournaments ?? MockData.allTournaments) {
      if (MockData.joinedIds.value.contains(tournament.id) &&
          !items.any((item) => item.tournamentId == tournament.id)) {
        items.add(_matchFromTournament(tournament));
      }
    }
  }

  Future<void> _loadMatches() async {
    final load = widget.onLoadMatches;
    if (load == null || _loadingMatches) return;
    setState(() {
      _loadingMatches = true;
      _loadError = null;
    });
    try {
      final matches = await load();
      if (!mounted) return;
      setState(() {
        _items = List<MatchItem>.of(matches);
        _sig = _signature(DateTime.now());
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error is ApiAuthException
            ? error.message
            : 'Unable to load matches. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loadingMatches = false);
    }
  }

  MatchItem _matchFromTournament(Tournament tournament) {
    final details = tournament.detail.split('|');
    final players = tournament.players.split('/');
    final perKill = tournament.perKill;
    return MatchItem(
      id: 'match_${tournament.id}',
      tournamentId: tournament.id,
      mode: tournament.mode,
      team: tournament.mode,
      map: details.length > 1 ? details[1].trim() : details.first.trim(),
      img: tournament.bg,
      prize: _parseAmount(tournament.prize),
      fee: _parseAmount(tournament.fee),
      joined: int.parse(players.first),
      slots: int.parse(players.last),
      perKill: perKill == null ? 0 : _parseAmount(perKill),
      startsInSecs: tournament.status == 'live' ? -600 : tournament.secs,
      room: tournament.roomId.isNotEmpty && tournament.roomPass.isNotEmpty
          ? MatchRoom(roomId: tournament.roomId, roomPass: tournament.roomPass)
          : null,
    );
  }

  int _parseAmount(String value) =>
      int.parse(value.replaceAll(RegExp(r'[^0-9]'), ''));

  @override
  void dispose() {
    _timer?.cancel();
    _refreshTimer?.cancel();
    MockData.joinedIds.removeListener(_onJoinedIdsChanged);
    _now.dispose();
    super.dispose();
  }

  void _onJoinedIdsChanged() {
    if (!mounted) return;
    _addJoinedTournamentItems(_items);
    setState(() => _sig = _signature(DateTime.now()));
  }

  // ---------------------------------------------------------- data
  List<MatchView> _views(DateTime now) {
    final all = <MatchView>[];
    for (final i in _items) {
      if (i.tournamentId != null &&
          !i.remote &&
          !MockData.joinedIds.value.contains(i.tournamentId) &&
          !_leaving.contains(i.id)) {
        continue;
      }
      final start = _base.add(Duration(seconds: i.startsInSecs));
      final end = start.add(Duration(minutes: i.durationMin));
      all.add(MatchView(i, start, end, now));
    }
    final wantDone = _tab == 'completed';
    final out = all.where((v) => v.completed == wantDone).toList();
    out.sort(
      (a, b) => wantDone ? b.end.compareTo(a.end) : a.start.compareTo(b.start),
    );
    return out;
  }

  String _signature(DateTime now) {
    final parts = _views(now).map(
      (v) =>
          '${v.item.id}${v.completed}${v.started}${v.item.room?.roomId ?? ''}${v.item.room?.roomPass ?? ''}',
    );
    return '$_tab|${parts.join(',')}';
  }

  Future<void> _copy(String v) async {
    final f = widget.onCopy;
    if (f != null) {
      await f(v);
    } else {
      await Clipboard.setData(ClipboardData(text: v));
    }
  }

  Future<void> _onLeave(String id) async {
    if (_leaving.contains(id)) return;
    final yes = await showLeaveConfirm(context);
    if (yes != true || !mounted) return;
    final f = widget.onLeave;
    final ok = f == null ? true : await f(id);
    if (ok && mounted) {
      final match = _items.firstWhere((item) => item.id == id);
      setState(() => _leaving.add(id));
      final tournamentId = match.tournamentId;
      if (tournamentId != null &&
          MockData.joinedIds.value.contains(tournamentId)) {
        MockData.joinedIds.value = Set<String>.of(MockData.joinedIds.value)
          ..remove(tournamentId);
        AuthSession.walletTotal.value += match.fee;
      }
    }
  }

  void _finishLeave(String id) {
    if (!mounted) return;
    setState(() {
      _items.removeWhere((e) => e.id == id);
      _leaving.remove(id);
      _sig = _signature(DateTime.now());
    });
  }

  void _setTab(String t) {
    if (t == _tab) return;
    setState(() {
      _tab = t;
      _sig = _signature(DateTime.now());
    });
  }

  // ---------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final views = _views(DateTime.now());
    final upcoming = _tab == 'upcoming';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            14,
            14,
            14,
            0,
          ).add(widget.bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rise(
                    key: const ValueKey('header'),
                    delayMs: 20,
                    child: _header(context),
                  ),
                  const SizedBox(height: 16),
                  _Rise(
                    key: const ValueKey('tabs'),
                    delayMs: 80,
                    child: _tabs(),
                  ),
                  const SizedBox(height: 16),
                  _Rise(
                    key: const ValueKey('list'),
                    delayMs: 140,
                    child: Column(
                      children: [
                        for (var i = 0; i < views.length; i++)
                          _cardItem(views[i], i),
                      ],
                    ),
                  ),
                  if (views.isEmpty && _loadingMatches)
                    const Padding(
                      padding: EdgeInsets.only(top: 42),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6EE7C3),
                        ),
                      ),
                    ),
                  if (views.isEmpty && !_loadingMatches && _loadError != null)
                    _Rise(
                      key: const ValueKey('load-error'),
                      delayMs: 200,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: _t(13, FontWeight.w500, Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadMatches,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  if (views.isEmpty && !_loadingMatches && _loadError == null)
                    _Rise(
                      key: const ValueKey('empty'),
                      delayMs: 200,
                      child: MatchesEmptyState(
                        title: upcoming
                            ? 'No upcoming matches'
                            : 'No completed matches yet',
                        subtitle: upcoming
                            ? 'Join a tournament and it will show up here.'
                            : 'Finished matches and your results will appear here.',
                        onBrowse: widget.onBrowseTournaments,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final fs = (w * .05).clamp(18.0, 22.0).toDouble();
    final shadow = [
      Shadow(
        color: rsC(0, 0, 0, .5),
        blurRadius: 14,
        offset: const Offset(0, 1),
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My Matches',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(
                  fs,
                  FontWeight.w700,
                  Colors.white,
                  h: 1.15,
                ).copyWith(shadows: shadow),
              ),
              Text(
                'Track • Play • Win',
                maxLines: 1,
                style: _t(
                  11,
                  FontWeight.w400,
                  rsC(156, 163, 199),
                ).copyWith(shadows: shadow),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        widget.walletChip ??
            WalletChip(balanceListenable: AuthSession.walletTotal),
      ],
    );
  }

  Widget _tabs() => Row(
    children: [
      Expanded(
        child: _TabBtn(
          label: 'Upcoming',
          path: _pClock,
          selected: _tab == 'upcoming',
          onTap: () => _setTab('upcoming'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _TabBtn(
          label: 'Completed',
          path: _pCheck,
          selected: _tab == 'completed',
          onTap: () => _setTab('completed'),
        ),
      ),
    ],
  );

  Widget _cardItem(MatchView v, int index) {
    final id = v.item.id;
    final leaving = _leaving.contains(id);
    final delay = index == 0
        ? 0
        : index == 1
        ? 70
        : index == 2
        ? 140
        : index == 3
        ? 210
        : 270;
    return _Rise(
      key: ValueKey('$_tab/$id'),
      delayMs: delay,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: leaving ? 0.0 : 1.0),
        duration: leaving ? _d(context, 380) : Duration.zero,
        curve: kRsEase,
        onEnd: () {
          if (leaving) _finishLeave(id);
        },
        builder: (_, f, child) => ClipRect(
          clipBehavior: f < 1
              ? Clip.hardEdge
              : Clip.none, // no clipping while idle, so the card shadow stays
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: f,
            child: Opacity(opacity: f, child: child),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: MatchCard(
            view: v,
            now: _now,
            imageBase: widget.imageBase,
            onCopy: _copy,
            onLeave: _onLeave,
          ),
        ),
      ),
    );
  }
}

// ===================================================================== TABS
class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.path,
    required this.selected,
    required this.onTap,
  });
  final String label, path;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RsPress(
      scale: .93,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1.0 : 0.0),
        duration: _d(context, 400),
        curve: kRsEase,
        builder: (_, t, _) {
          final text = Color.lerp(rsC(195, 208, 203), rsC(234, 255, 247), t)!;
          final glow = .1 + .16 * t;
          return Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Color.lerp(
                rsC(255, 255, 255, .06),
                rsC(12, 22, 20, .45),
                t,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    rsC(110, 230, 195, 0),
                    rsC(110, 230, 195, .26),
                    t,
                  )!,
                  Color.lerp(rsC(27, 111, 92, 0), rsC(27, 111, 92, .2), t)!,
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  rsC(255, 255, 255, .14),
                  rsC(140, 240, 210, .38),
                  t,
                )!,
              ),
              boxShadow: [
                BoxShadow(
                  color: rsC(0, 0, 0, .35 * t),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 24,
                  right: 24,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rsC(255, 255, 255, 0),
                          rsC(255, 255, 255, glow),
                          rsC(255, 255, 255, glow),
                          rsC(255, 255, 255, 0),
                        ],
                        stops: const [0, .12, .88, 1],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.string(
                        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#ffffff" '
                        'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$path</svg>',
                        width: 16,
                        height: 16,
                        colorFilter: ColorFilter.mode(text, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 7),
                      Text(label, style: _t(13, FontWeight.w500, text)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
