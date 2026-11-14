import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/mock/mock_data.dart';
import '../../../core/rs_kit.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/wallet_chip.dart';
import '../../profile/data/profile_mock.dart';
import 'game_id_popup.dart';
import 'loot_banner.dart';
import 'swords_badge.dart';

/// Flutter home page backed by the shared tournament repository.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onSaveGameId,
    this.onTournamentTimerEnd,
    this.onOpenTournament,
    this.onAppOpened,
    this.tournaments,
  });

  final Future<GameIdResult> Function(String ign, String uid)? onSaveGameId;
  final VoidCallback? onTournamentTimerEnd;
  final void Function(String tournamentId)? onOpenTournament;
  final Future<void> Function(BuildContext context)? onAppOpened;
  final List<Tournament>? tournaments;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<HeroSlide> _slides;
  late final ValueNotifier<List<int>> _left;
  final ValueNotifier<int> _slideIdx = ValueNotifier<int>(0);
  Timer? _tick;
  Timer? _gid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final onAppOpened = widget.onAppOpened;
      if (mounted && onAppOpened != null) {
        unawaited(onAppOpened(context));
      }
    });
    _slides = _buildHeroSlides(widget.tournaments ?? const <Tournament>[]);
    _left = ValueNotifier<List<int>>(
      _slides.map((slide) => slide.secs).toList(),
    );
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final l = List<int>.from(_left.value);
      var timerEnded = false;
      for (int i = 0; i < l.length; i++) {
        if (l[i] > 0) {
          l[i]--;
          timerEnded |= l[i] == 0 && _slides[i].tournament;
        }
      }
      _left.value = l;
      if (timerEnded) widget.onTournamentTimerEnd?.call();
    });
    _scheduleGameId();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tournaments != widget.tournaments) {
      _slides = _buildHeroSlides(widget.tournaments ?? const <Tournament>[]);
      _left.value = _slides.map((slide) => slide.secs).toList();
      _slideIdx.value = 0;
    }
  }

  List<HeroSlide> _buildHeroSlides(List<Tournament> tournaments) {
    final liveTournaments = tournaments
        .where((tournament) => !tournament.loot && tournament.status == 'live')
        .toList(growable: false);
    final featuredTournaments = liveTournaments.isNotEmpty
        ? liveTournaments
        : tournaments
              .where(
                (tournament) =>
                    !tournament.loot && tournament.status == 'upcoming',
              )
              .toList(growable: false);
    if (featuredTournaments.isEmpty) {
      return const <HeroSlide>[
        HeroSlide(
          tournament: false,
          mode: 'No tournaments yet',
          line: 'Check back soon for upcoming tournaments.',
          img: 'main3_banner.jpg',
        ),
      ];
    }
    return featuredTournaments
        .take(4)
        .map((tournament) {
          final live = tournament.status == 'live';
          return HeroSlide(
            tournament: true,
            tournamentId: tournament.id,
            live: live,
            game: tournament.game,
            mode: tournament.mode,
            team: tournament.teamType,
            prize: tournament.prize,
            fee: tournament.fee,
            players: tournament.bookedPlayers,
            perKill: tournament.perKill,
            secs: tournament.secs,
            label: tournament.label,
            img: tournament.bg,
            bannerUrl: tournament.bannerUrl,
          );
        })
        .toList(growable: false);
  }

  Future<void> _scheduleGameId() async {
    if (AuthSession.gameOk.value || RsSession.gidAsked) return;
    if (!mounted) return;
    _gid = Timer(const Duration(milliseconds: 4500), () {
      if (!mounted || RsSession.gidAsked || AuthSession.gameOk.value) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      RsSession.gidAsked = true;
      showGameIdPopup(context, onSave: widget.onSaveGameId);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _gid?.cancel();
    _left.dispose();
    _slideIdx.dispose();
    super.dispose();
  }

  Widget _pad(Widget c, {double top = 0, double bottom = 0}) =>
      Padding(padding: EdgeInsets.fromLTRB(14, top, 14, bottom), child: c);

  void _go(String route) => Navigator.of(context).pushNamed(route);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AppShell(
      fadeTransition: true,
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.only(
                top: 14 + mq.padding.top,
                bottom: 100 + mq.padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RsIn(delay: .02, child: _pad(_header(context))),
                  RsIn(
                    delay: .08,
                    child: _pad(
                      _Hero(
                        slides: _slides,
                        left: _left,
                        index: _slideIdx,
                        onOpenTournament: widget.onOpenTournament,
                      ),
                      top: 16,
                    ),
                  ),
                  RsIn(
                    delay: .12,
                    child: _pad(
                      _Dots(index: _slideIdx, count: _slides.length),
                      top: 10,
                    ),
                  ),
                  RsIn(
                    delay: .16,
                    child: _pad(
                      _secHead(
                        'Upcoming Tournaments',
                        'flame',
                        link: 'See All',
                        onLink: () => _go('/tournaments'),
                      ),
                      top: 22,
                      bottom: 12,
                    ),
                  ),
                  RsIn(delay: .2, child: _tournamentRow(context)),
                  RsIn(
                    delay: .24,
                    child: _pad(
                      _secHead('FREE MATCHES!', 'flame'),
                      top: 22,
                      bottom: 12,
                    ),
                  ),
                  RsIn(delay: .28, child: _pad(const LootBanner())),
                  RsIn(
                    delay: .32,
                    child: _pad(
                      _secHead('NOTICE', 'clock'),
                      top: 22,
                      bottom: 12,
                    ),
                  ),
                  RsIn(delay: .36, child: _pad(const _Rewards())),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header --
  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              const SwordsBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: AuthSession.ign,
                      builder: (context, ign, _) =>
                          ValueListenableBuilder<String>(
                            valueListenable: AuthSession.name,
                            builder: (context, name, _) {
                              final displayName = ign.trim().isNotEmpty
                                  ? ign
                                  : name;
                              return RsIn(
                                delay: .3,
                                dur: .9,
                                dy: 10,
                                blur: 6,
                                child: Text(
                                  displayName.isEmpty ? 'Player' : displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: rsT(
                                    rsFluid(context, 19, 5.6, 23),
                                    w: FontWeight.w700,
                                    h: 1.2,
                                  ),
                                ),
                              );
                            },
                          ),
                    ),
                    const Tagline(),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        WalletChip(balanceListenable: AuthSession.walletTotal),
      ],
    );
  }

  // ------------------------------------------------------------ section head --
  Widget _secHead(
    String title,
    String icon, {
    String? link,
    VoidCallback? onLink,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              RsIcon(icon, size: 22, color: kRsAmber, filled: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: rsT(16, w: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        if (link != null)
          RsPress(
            onTap: onLink,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(link, style: rsT(12, color: kRsG2)),
                  const SizedBox(width: 3),
                  const RsIcon('arrow', size: 12, color: kRsG2),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------- upcoming tournaments --
  Widget _tournamentRow(BuildContext context) {
    final w = rsFluid(context, 165, 46, 210);
    const h = 230.0;
    final tournaments = (widget.tournaments ?? const <Tournament>[])
        .where(
          (tournament) => !tournament.loot && tournament.status == 'upcoming',
        )
        .take(4)
        .toList(growable: false);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: MockData.joinedIds,
      builder: (context, joinedIds, _) {
        final children = <Widget>[];
        if (tournaments.isEmpty) {
          children.add(_emptyStack(w, h));
        } else {
          for (int i = 0; i < tournaments.length; i++) {
            if (i > 0) children.add(const SizedBox(width: 12));
            final t = tournaments[i];
            children.add(
              SizedBox(
                width: w,
                height: h,
                child: _TCard(
                  t: t,
                  joined: joinedIds.contains(t.id),
                  onJoin: () => _go('/tournament/${t.id}'),
                ),
              ),
            );
          }
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
      },
    );
  }

  Widget _emptyStack(double w, double h) {
    Widget layer(double top, double left, double o) => Positioned(
      top: top,
      bottom: top,
      left: left,
      right: -left,
      child: Opacity(
        opacity: o,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF141A19),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
    return SizedBox(
      width: w + 36,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(width: w, height: h),
          layer(28, 32, .3),
          layer(14, 16, .6),
          Positioned(
            left: 0,
            top: 0,
            width: w,
            height: h,
            child: RsGlass(
              radius: 24,
              blur: 22,
              base: rsC(12, 16, 15, .5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [rsW(.13), rsW(.035), rsW(.07)],
                stops: const [0, .45, 1],
              ),
              border: rsW(.14),
              topLight: .16,
              shadows: [
                BoxShadow(
                  color: rsK(.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No upcoming tournaments',
                          style: rsT(14, w: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'New matches will appear here soon',
                          style: rsT(11, color: kRsMuted),
                        ),
                      ],
                    ),
                  ),
                  const Positioned.fill(
                    child: RsShine(widthFactor: .35, alpha: .22),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HERO carousel
// =============================================================================
class _Hero extends StatefulWidget {
  const _Hero({
    required this.slides,
    required this.left,
    required this.index,
    this.onOpenTournament,
  });
  final List<HeroSlide> slides;
  final ValueNotifier<List<int>> left;
  final ValueNotifier<int> index;
  final void Function(String tournamentId)? onOpenTournament;
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with WidgetsBindingObserver {
  final PageController _pc = PageController();
  Timer? _auto;
  Timer? _resume;
  bool _resetScheduled = false;
  bool _init = false;
  bool _reduce = false;
  int get _n => widget.slides.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _reduce = rsReduce(context);
    if (!_reduce) _play();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_reduce) _play();
    } else {
      _stop();
    }
  }

  @override
  void didUpdateWidget(covariant _Hero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides != widget.slides) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pc.hasClients) _pc.jumpToPage(0);
        widget.index.value = 0;
      });
    }
  }

  void _play() {
    _stop();
    _auto = Timer.periodic(
      const Duration(milliseconds: 3500),
      (_) => _advance(),
    );
  }

  void _stop() {
    _auto?.cancel();
    _auto = null;
  }

  void _advance() {
    if (!_pc.hasClients || _pc.page == null) return;
    final cur = _pc.page!.round();
    if (cur >= _n) return;
    _pc.animateToPage(
      cur + 1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auto?.cancel();
    _resume?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = rsFluid(context, 250, 70, 300);
    return RsGlass(
      radius: 26,
      border: rsW(.14),
      topLight: .14,
      shadows: [
        BoxShadow(color: rsK(.4), blurRadius: 32, offset: const Offset(0, 12)),
      ],
      child: SizedBox(
        height: h,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            // seamless endless loop: the cloned first slide jumps back to the real one
            if (!_resetScheduled &&
                _pc.hasClients &&
                _pc.page != null &&
                _pc.page!.round() >= _n) {
              _resetScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_pc.hasClients &&
                    _pc.page != null &&
                    _pc.page!.round() >= _n) {
                  _pc.jumpToPage(0);
                }
                _resetScheduled = false;
              });
            }
            return false;
          },
          child: Listener(
            onPointerDown: (_) {
              _resume?.cancel();
              _stop();
            },
            onPointerUp: (_) => _scheduleResume(),
            onPointerCancel: (_) => _scheduleResume(),
            child: PageView.builder(
              controller: _pc,
              itemCount: _n + 1,
              onPageChanged: (i) => widget.index.value = i % _n,
              itemBuilder: (context, i) {
                final slide = widget.slides[i % _n];
                final tournamentId = slide.tournamentId;
                return _Slide(
                  s: slide,
                  idx: i % _n,
                  left: widget.left,
                  onTap: tournamentId == null
                      ? null
                      : () => widget.onOpenTournament?.call(tournamentId),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleResume() {
    _resume?.cancel();
    _resume = Timer(const Duration(seconds: 3), () {
      if (!_reduce && mounted) _play();
    });
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.s,
    required this.idx,
    required this.left,
    this.onTap,
  });
  final HeroSlide s;
  final int idx;
  final ValueNotifier<List<int>> left;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0A0A0A)),
          if (s.bannerUrl.isNotEmpty)
            Image.network(
              s.bannerUrl,
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
              errorBuilder: (_, _, _) =>
                  RsImage(s.img, alignment: Alignment.centerRight),
            )
          else
            RsImage(s.img, alignment: Alignment.centerRight),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [rsK(.88), rsK(.45), rsK(.05)],
                stops: const [0, .55, 1],
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: s.tournament ? _tournamentTop(context) : _promoTop(context),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rsK(.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FREE FIRE',
                    style: rsT(12, w: FontWeight.w700, ls: 1, h: 1.2),
                  ),
                  Text(
                    'GARENA',
                    style: rsT(6, ls: 2, color: const Color(0xFFCBD0F0)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: s.tournament
                ? Align(
                    alignment: Alignment.centerRight,
                    child: _timer(context),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: _viewButton(context),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tournamentTop(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pill(
          label: s.live ? 'LIVE NOW' : 'UPCOMING',
          dot: s.live ? kRsRed : kRsG2,
          blink: s.live,
        ),
        const SizedBox(height: 8),
        Text(
          s.game,
          style: rsT(rsFluid(context, 28, 8.5, 34), w: FontWeight.w700, h: 1.1),
        ),
        Text(
          s.mode,
          style: rsT(
            rsFluid(context, 17, 5, 21),
            w: FontWeight.w500,
            ls: 1,
            h: 1.2,
            color: const Color(0xFFCBD0F0),
          ),
        ),
        if (s.team.isNotEmpty) ...[
          const SizedBox(height: 4),
          _Pill(
            label: '${s.team.toUpperCase()} MATCH',
            dot: kRsCyan,
            blink: false,
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Stat(
              icon: 'trophy',
              color: kRsGold,
              value: s.prize,
              label: 'Prize Pool',
            ),
            _Stat(
              icon: 'ticket',
              color: kRsBlue,
              value: s.fee,
              label: 'Entry Fee',
            ),
            _Stat(
              icon: 'users',
              color: kRsCyan,
              value: s.players,
              label: 'Players',
            ),
            if (s.perKill != null)
              _Stat(
                icon: 'swords',
                color: Colors.white,
                value: s.perKill!,
                label: 'Per Kill',
              ),
          ],
        ),
      ],
    );
  }

  Widget _promoTop(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Pill(label: 'FREE FIRE TOURNAMENTS', dot: kRsG2, blink: false),
        const SizedBox(height: 8),
        Text(
          s.mode,
          style: rsT(rsFluid(context, 24, 7.5, 30), w: FontWeight.w700, h: 1.1),
        ),
        const SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: .7,
          alignment: Alignment.centerLeft,
          child: Text(
            s.line,
            style: rsT(12, h: 1.5, color: const Color(0xFFCBD0F0)),
          ),
        ),
      ],
    );
  }

  Widget _timer(BuildContext context) {
    final muted = rsT(10, color: kRsMuted);
    return RsGlass(
      radius: 18,
      blur: 14,
      base: rsC(8, 18, 16, .62),
      border: rsW(.14),
      topLight: .1,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.label, style: muted),
            ValueListenableBuilder<List<int>>(
              valueListenable: left,
              builder: (context, l, _) {
                final showDays = l[idx] >= 86400;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showDays
                          ? rsClockWithDays(l[idx])
                          : rsClock(l[idx], ' : '),
                      style: rsT(
                        rsFluid(context, 18, 5.6, 22),
                        w: FontWeight.w700,
                        ls: 1,
                        h: 1.2,
                        color: const Color(0xFFD8FFF1),
                        tabular: true,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (showDays)
                          Text('Days', style: rsT(9, color: kRsMuted)),
                        Text('Hrs', style: rsT(9, color: kRsMuted)),
                        Text('Min', style: rsT(9, color: kRsMuted)),
                        Text('Sec', style: rsT(9, color: kRsMuted)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewButton(BuildContext context) {
    return RsPress(
      scale: .94,
      onTap: () => Navigator.of(context).pushNamed('/tournaments'),
      child: RsGlass(
        radius: 999,
        blur: 18,
        base: rsC(10, 14, 13, .35),
        gradient: rsBtnGradient(),
        border: rsW(.38),
        topLight: .4,
        shadows: [
          BoxShadow(color: rsK(.4), blurRadius: 22, offset: const Offset(0, 8)),
        ],
        child: Stack(
          children: [
            SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'View Tournaments',
                    style: rsT(14, w: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: RsShine()),
          ],
        ),
      ),
    );
  }
}

/// LIVE NOW / UPCOMING / FREE FIRE TOURNAMENTS pill
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.dot, required this.blink});
  final String label;
  final Color dot;
  final bool blink;
  @override
  Widget build(BuildContext context) {
    Widget dotW = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
    );
    if (blink && !rsReduce(context)) {
      dotW = RsLoop(
        builder: (c, s) {
          final p = (s / 1.2) % 1;
          final o = 1 - .7 * (1 - (2 * p - 1).abs());
          return Opacity(
            opacity: o,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
            ),
          );
        },
      );
    }
    return RsGlass(
      radius: 999,
      blur: 12,
      base: rsK(.45),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dotW,
          const SizedBox(width: 6),
          Text(label, style: rsT(10, w: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final String icon;
  final Color color;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return RsGlass(
      radius: 16,
      blur: 14,
      base: rsC(8, 18, 16, .55),
      border: rsW(.12),
      topLight: .1,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RsIcon(icon, size: 19, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: rsT(
                  rsFluid(context, 12, 3.6, 14),
                  w: FontWeight.w700,
                  h: 1.2,
                ),
              ),
              Text(label, style: rsT(9, color: kRsMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.index, required this.count});
  final ValueNotifier<int> index;
  final int count;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: index,
      builder: (context, cur, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == cur ? 16 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == cur ? kRsG2 : const Color(0xFF3D4744),
                borderRadius: BorderRadius.circular(i == cur ? 4 : 3.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// tournament card
// =============================================================================
class _TCard extends StatelessWidget {
  const _TCard({required this.t, required this.joined, required this.onJoin});
  final Tournament t;
  final bool joined;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final muted = rsT(9, color: kRsMuted);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onJoin,
      child: RsGlass(
        radius: 24,
        base: const Color(0xFF0A0A0A),
        border: rsW(.14),
        topLight: .16,
        shadows: [
          BoxShadow(
            color: rsK(.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
        child: Stack(
          fit: StackFit.expand,
          children: [
            t.bannerUrl.isNotEmpty
                ? Image.network(
                    t.bannerUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const RsImage('upcoming.jpg'),
                  )
                : RsImage(t.bg),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [rsK(.05), rsK(.88), rsK(.88)],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _logo(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.game,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: rsT(13, w: FontWeight.w700, h: 1.2),
                            ),
                            Text(
                              t.mode,
                              style: rsT(11, color: const Color(0xFFCBD0F0)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _tStat('trophy', kRsGold, t.prize, 'Prize Pool', muted),
                      const SizedBox(width: 12),
                      _tStat('ticket', kRsBlue, t.fee, 'Entry Fee', muted),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${t.bookedPlayers} Players',
                    style: rsT(10, color: kRsMuted),
                  ),
                  if (t.perKill != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const RsIcon('swords', size: 13, color: kRsGold),
                        const SizedBox(width: 4),
                        Text(
                          '${t.perKill} Per Kill',
                          style: rsT(10, color: kRsGold),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const RsIcon('clock', size: 11, color: kRsG2),
                      const SizedBox(width: 5),
                      Text(
                        t.when,
                        maxLines: 1,
                        style: rsT(11, color: const Color(0xFFD1D5F0)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(left: 12, right: 12, bottom: 12, child: _join()),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: rsC(34, 211, 238, .18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: rsC(34, 211, 238, .45)),
                ),
                child: Text(
                  'UPCOMING',
                  style: rsT(8, w: FontWeight.w600, color: kRsCyan),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    return RsGlass(
      radius: 11,
      blur: 10,
      base: rsC(8, 14, 13, .7),
      border: rsW(.26),
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(
          child: t.logo == 'cod'
              ? Text('COD', style: rsT(8, w: FontWeight.w700, h: 1))
              : const RsIcon('flame', size: 20, color: Color(0xFFFB923C)),
        ),
      ),
    );
  }

  Widget _tStat(String icon, Color c, String v, String label, TextStyle small) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RsIcon(icon, size: 13, color: c),
            const SizedBox(width: 3),
            Text(v, style: rsT(13, w: FontWeight.w700)),
          ],
        ),
        Text(label, style: small),
      ],
    );
  }

  Widget _join() {
    return RsPress(
      onTap: onJoin,
      child: RsGlass(
        radius: 999,
        blur: 18,
        base: joined ? rsC(8, 24, 16, .5) : rsC(10, 14, 13, .35),
        gradient: joined
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [rsC(74, 222, 128, .34), rsC(21, 128, 61, .26)],
              )
            : rsBtnGradient(),
        border: joined ? rsC(134, 239, 172, .5) : rsW(.38),
        topLight: joined ? .28 : .4,
        shadows: [
          BoxShadow(
            color: rsK(.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        child: Stack(
          children: [
            SizedBox(
              height: 38,
              width: double.infinity,
              child: Center(
                child: Text(
                  joined ? 'Joined' : 'Join',
                  style: rsT(
                    14,
                    w: FontWeight.w600,
                    color: joined ? const Color(0xFFDCFCE7) : Colors.white,
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: RsShine(alpha: .3)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// NOTICE: rewards banner
// =============================================================================
class _Rewards extends StatelessWidget {
  const _Rewards();
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: RsGlass(
        radius: 26,
        base: const Color(0xFF050807),
        shadows: [
          BoxShadow(
            color: rsK(.5),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
        child: Stack(
          children: [
            const Positioned.fill(child: RsZoomImage('rewards_banner.jpg')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: box.maxWidth * .86,
                      child: _info(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RsGlass(
          radius: 999,
          blur: 12,
          base: rsC(251, 191, 36, .12),
          border: rsC(251, 191, 36, .5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RsIcon('clock', size: 14, color: kRsGold),
              const SizedBox(width: 6),
              Text(
                '24 HRS',
                style: rsT(
                  11,
                  w: FontWeight.w700,
                  ls: 11 * .16,
                  color: kRsGold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'REWARDS CAN TAKE\nUP TO 24 HRS',
          style: rsT(
            rsFluid(context, 18, 5.8, 26),
            w: FontWeight.w700,
            h: 1.1,
            ls: rsFluid(context, 18, 5.8, 26) * .03,
            color: kRsG2,
            shadows: [
              Shadow(
                color: rsK(.7),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        RsGlass(
          radius: 16,
          blur: 16,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [rsW(.18), rsW(.06)],
          ),
          border: rsW(.2),
          topLight: .25,
          shadows: [
            BoxShadow(
              color: rsK(.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text.rich(
            TextSpan(
              style: rsT(12, h: 1.5, color: const Color(0xFFE9F2EE)),
              children: [
                const TextSpan(text: 'Winning amount is given within '),
                TextSpan(
                  text: '24 hours',
                  style: rsT(12, w: FontWeight.w700, h: 1.5, color: kRsGold),
                ),
                const TextSpan(
                  text:
                      ' after the match ends. Prize and kill rewards are added to your wallet.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
