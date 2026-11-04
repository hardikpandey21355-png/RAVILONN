// lib/features/tournament_detail/presentation/tournament_detail_page.dart
//
// Tournament detail / join page (UI only) — Flutter clone of tournament.html.
//
// The other files of this folder are `part`s of this library, sharing the
// tournament-specific visual components below.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/mock/mock_data.dart' show inr, rsClock;
import '../../../core/rs_kit.dart' show RsPress, rsC, rsT;
import '../data/tournament_detail_mock.dart';

part 'detail_facts.dart';
part 'detail_hero.dart';
part 'detail_info_groups.dart';
part 'detail_toast.dart';
part 'join_dock.dart';
part 'join_sheet.dart';
part 'slot_grid.dart';

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);

TextStyle _t(
  double size,
  FontWeight weight,
  Color color, {
  double? ls,
  double? h,
}) {
  return rsT(size, w: weight, color: color, ls: ls, h: h);
}

Widget _icon(String innerSvgPath, String colorHex, double size) {
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="$colorHex" stroke-width="2" stroke-linecap="round" '
    'stroke-linejoin="round">$innerSvgPath</svg>',
    width: size,
    height: size,
  );
}

// Icon paths (from _icons.html)
const String _icBack = '<path d="M19 12H5M11 6l-6 6 6 6"/>';
const String _icTrophy =
    '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>';
const String _icTicket =
    '<path d="M3 9a2 2 0 0 0 0 6v3h18v-3a2 2 0 0 1 0-6V6H3z"/><path d="M13 6v12" stroke-dasharray="2 2"/>';
const String _icUsers =
    '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6.5 6.5 0 0 1 3.5 6"/>';
const String _icSwords =
    '<path d="M4 4l9 9M20 4l-9 9M3 21l4-4M21 21l-4-4M8 16l-3 3M16 16l3 3"/>';
const String _icFlame =
    '<path d="M12 3c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z"/>';
const String _icCheck = '<path d="M5 12l5 5 9-10"/>';
const String _icPlus = '<path d="M12 5v14M5 12h14"/>';
const String _icWallet =
    '<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16" cy="14" r="1"/>';

// Colors
const Color _white = Colors.white;
const Color _muted = Color(0xFF9CA3C7);
const Color _gold = Color(0xFFFBBF24);
const Color _lootGold = Color(0xFFF7D774);
const Color _boxBg = Color(0xFF0C0C0C);
const Color _boxLine = Color(0xFF222222);

const LinearGradient _gbtnGrad = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[
    Color.fromRGBO(110, 230, 195, .26),
    Color.fromRGBO(27, 111, 92, .2),
  ],
);
const Color _gbtnBase = Color.fromRGBO(12, 22, 20, .45);

/// Indian grouping: 1250 -> "1,250", 100000 -> "1,00,000".
String _inr(int n) => inr(n);

/// HH:MM:SS (zero padded).
String _rsClock(int secs) => rsClock(secs);

double _vw(BuildContext context, double min, double vw, double max) {
  final w = MediaQuery.of(context).size.width * vw / 100;
  return w.clamp(min, max).toDouble();
}

Duration _ms(BuildContext context, int ms) {
  return MediaQuery.of(context).disableAnimations
      ? Duration.zero
      : Duration(milliseconds: ms);
}

Widget _line(double height, Widget child, [double align = .3]) {
  return SizedBox(
    height: height,
    child: Align(alignment: Alignment(-1, align), child: child),
  );
}

/// Outer shadow that is clipped away inside the box (like CSS box-shadow).
class _Sh {
  const _Sh(this.dy, this.blur, this.color);
  final double dy;
  final double blur;
  final Color color;
}

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.r, this.shadows);
  final double r;
  final List<_Sh> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty || size.isEmpty) return;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(r, math.min(size.width, size.height) / 2)),
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rr.outerRect.inflate(400)),
      Path()..addRRect(rr),
    );
    canvas.save();
    canvas.clipPath(outside);
    for (final s in shadows) {
      final paint = Paint()..color = s.color;
      if (s.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      }
      canvas.drawRRect(rr.shift(Offset(0, s.dy)), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) {
    if (old.r != r || old.shadows.length != shadows.length) return true;
    for (var i = 0; i < shadows.length; i++) {
      final a = old.shadows[i], b = shadows[i];
      if (a.dy != b.dy || a.blur != b.blur || a.color != b.color) {
        return true;
      }
    }
    return false;
  }
}

/// Inset highlight: `inset 0 1px 0 <color>`.
class _HLPainter extends CustomPainter {
  const _HLPainter(this.r, this.color);
  final double r;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(r, math.min(size.width, size.height) / 2)),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(rr)
      ..addRRect(rr.shift(const Offset(0, 1)));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HLPainter old) => old.r != r || old.color != color;
}

/// Generic glass surface (bg colour + gradient, 1px border, inset highlight,
/// clipped shadows, optional backdrop blur / clipping).
class _Surface extends StatelessWidget {
  const _Surface({
    required this.r,
    this.color,
    this.gradient,
    this.border,
    this.hl,
    this.shadows = const <_Sh>[],
    this.padding,
    this.blur = 0,
    this.child,
  });

  final double r;
  final Color? color;
  final Gradient? gradient;
  final Color? border;
  final Color? hl;
  final List<_Sh> shadows;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final inner = math.max(r - 1, 0.0);
    Widget c = child ?? const SizedBox.shrink();
    if (padding != null) c = Padding(padding: padding!, child: c);
    if (hl != null) {
      c = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          c,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HLPainter(inner, hl!)),
            ),
          ),
        ],
      );
    }
    Widget box = Container(
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(r),
        border: border == null ? null : Border.all(color: border!, width: 1),
      ),
      child: c,
    );
    if (blur > 0) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: box,
        ),
      );
    }
    if (shadows.isNotEmpty) {
      box = CustomPaint(painter: _ShadowPainter(r, shadows), child: box);
    }
    return box;
  }
}

/// `.glass` (common.css): 135deg white .14 -> .04, blur 14, border .22.
class _Glass extends StatelessWidget {
  const _Glass({required this.r, this.padding, this.child});
  final double r;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      r: r,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Color.fromRGBO(255, 255, 255, .14),
          Color.fromRGBO(255, 255, 255, .04),
        ],
      ),
      border: _c(255, 255, 255, .22),
      hl: _c(255, 255, 255, .25),
      shadows: const <_Sh>[_Sh(6, 20, Color.fromRGBO(0, 0, 0, .35))],
      blur: 14,
      padding: padding,
      child: child,
    );
  }
}

enum _BV { primary, ghost, green }

/// `.btn` (height 46, radius 14) with primary / ghost / green styles and the
/// golden loot theme.
class _Btn extends StatelessWidget {
  const _Btn({
    required this.variant,
    required this.loot,
    required this.label,
    required this.onTap,
    this.iconPath,
    this.off = false,
    this.disabled = false,
  });

  final _BV variant;
  final bool loot;
  final String label;
  final VoidCallback? onTap;
  final String? iconPath;
  final bool off;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    Color fg;
    String hex;
    Color border;
    Color? base;
    Gradient? grad;
    Color? hl;
    List<_Sh> sh = const <_Sh>[];
    double blur = 0;

    const shadow = <_Sh>[_Sh(6, 18, Color.fromRGBO(0, 0, 0, .35))];

    if (loot) {
      if (variant == _BV.primary) {
        fg = const Color(0xFF3B2402);
        hex = '#3b2402';
        border = _c(255, 241, 176, .7);
        grad = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFFFF0B0),
            Color(0xFFF7D774),
            Color(0xFFD9A21F),
          ],
          stops: <double>[0, .45, 1],
        );
      } else if (variant == _BV.ghost) {
        fg = _lootGold;
        hex = '#f7d774';
        border = _c(247, 215, 116, .5);
        base = _c(247, 215, 116, .08);
      } else {
        fg = _lootGold;
        hex = '#f7d774';
        border = _c(247, 215, 116, .6);
        base = _c(247, 215, 116, .12);
      }
    } else if (variant == _BV.primary) {
      fg = const Color(0xFFEAFFF7);
      hex = '#eafff7';
      border = _c(140, 240, 210, .38);
      base = _gbtnBase;
      grad = _gbtnGrad;
      hl = _c(255, 255, 255, .26);
      sh = shadow;
      blur = 18;
    } else if (variant == _BV.ghost) {
      fg = _white;
      hex = '#ffffff';
      border = _c(255, 255, 255, .18);
      base = _c(20, 44, 38, .5);
      grad = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(255, 255, 255, .15),
          Color.fromRGBO(255, 255, 255, .04),
        ],
      );
      hl = _c(255, 255, 255, .2);
      sh = shadow;
      blur = 18;
    } else {
      fg = const Color(0xFFDCFCE7);
      hex = '#dcfce7';
      border = _c(134, 239, 172, .5);
      base = _c(8, 24, 16, .5);
      grad = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(74, 222, 128, .34),
          Color.fromRGBO(21, 128, 61, .26),
        ],
      );
      hl = _c(255, 255, 255, .28);
      sh = shadow;
    }

    final text = Text(label, style: _t(14, FontWeight.w600, fg, h: 1.5));
    final Widget content = iconPath == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _icon(iconPath!, hex, 17),
              const SizedBox(width: 7),
              Flexible(child: text),
            ],
          );

    final active = onTap != null && !disabled;
    return Opacity(
      opacity: disabled ? .5 : (off ? .55 : 1),
      child: RsPress(
        scale: .98,
        duration: const Duration(milliseconds: 300),
        enabled: active,
        onTap: active ? onTap : null,
        child: SizedBox(
          height: 46,
          width: double.infinity,
          child: _Surface(
            r: 14,
            color: base,
            gradient: grad,
            border: border,
            hl: hl,
            shadows: sh,
            blur: blur,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TournamentDetailPage
// ---------------------------------------------------------------------------

class TournamentDetailPage extends StatefulWidget {
  const TournamentDetailPage({
    super.key,
    required this.tournament,
    this.walletChip,
    required this.balance,
    this.gameOk = false,
    this.joined = false,
    this.onBack,
    this.onRefreshGame,
    this.onLoadSlots,
    this.onJoin,
    this.onPay,
    this.onOpenProfile,
    this.onViewMatches,
    this.onBrowseTournaments,
    this.onJoined,
  });

  final TournamentDetail tournament;

  /// Header right widget. Default: simple "₹ 1,250" pill (live balance).
  final Widget? walletChip;

  /// Wallet total (can be updated from outside).
  final int balance;

  /// Game ID (name + UID) saved in Profile.
  final bool gameOk;

  /// Already joined this tournament.
  final bool joined;

  final VoidCallback? onBack;

  /// Called when Join is pressed: re-check the game status. null => keep.
  final Future<bool> Function()? onRefreshGame;

  /// null => mock (500ms).
  final Future<SlotsResult> Function()? onLoadSlots;

  /// null => mock (800ms, success).
  final Future<JoinResult> Function(int slot)? onJoin;

  /// Add-money sheet "Pay". null => mock (700ms, success).
  final Future<PayResult> Function(int amount)? onPay;

  final VoidCallback? onOpenProfile;
  final VoidCallback? onViewMatches;
  final VoidCallback? onBrowseTournaments;

  /// 450ms after a successful join (navigate away from here).
  final VoidCallback? onJoined;

  @override
  State<TournamentDetailPage> createState() => _TournamentDetailPageState();
}

class _TournamentDetailPageState extends State<TournamentDetailPage> {
  late int _bal;
  late bool _gameOk;
  late bool _joined;

  final GlobalKey<JoinSheetState> _sheet = GlobalKey<JoinSheetState>();
  final GlobalKey<DetailToastState> _toast = GlobalKey<DetailToastState>();

  @override
  void initState() {
    super.initState();
    _bal = widget.balance;
    _gameOk = widget.gameOk;
    _joined = widget.joined;
    HardwareKeyboard.instance.addHandler(_onKey);
    if (widget.onRefreshGame != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshGame());
    }
  }

  @override
  void didUpdateWidget(TournamentDetailPage old) {
    super.didUpdateWidget(old);
    if (old.balance != widget.balance) _bal = widget.balance;
    if (old.gameOk != widget.gameOk) _gameOk = widget.gameOk;
    if (old.joined != widget.joined) _joined = widget.joined;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.escape &&
        (_sheet.currentState?.isOpen ?? false)) {
      _sheet.currentState?.close();
      return true;
    }
    return false;
  }

  void _showToast(String m) => _toast.currentState?.show(m);

  Future<void> _refreshGame() async {
    final f = widget.onRefreshGame;
    if (f == null) return;
    try {
      final ok = await f();
      if (mounted) setState(() => _gameOk = ok);
    } catch (e) {
      debugPrint('TournamentDetailPage: onRefreshGame failed ($e)');
    }
  }

  Future<void> _onJoinTap() async {
    await _refreshGame();
    if (!mounted) return;
    final t = widget.tournament;
    if (t.full) {
      _showToast('All slots are full');
      return;
    }
    if (!_gameOk) {
      _sheet.currentState?.open(SheetMode.game);
      return;
    }
    final need = t.fee - _bal;
    if (need > 0) {
      _showToast('Add ₹${_inr(need)} more to join');
      return;
    }
    _sheet.currentState?.open(SheetMode.join);
  }

  void _onJoinedDone() {
    if (!mounted) return;
    setState(() => _joined = true);
    widget.onJoined?.call();
  }

  Widget _header(BuildContext context, bool loot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              RsPress(
                scale: .98,
                duration: const Duration(milliseconds: 300),
                onTap: widget.onBack,
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: _Glass(
                    r: 19,
                    child: Center(child: _icon(_icBack, '#ffffff', 20)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Details',
                      style: _t(
                        _vw(context, 18, 5, 22),
                        FontWeight.w700,
                        _white,
                        h: 1.15,
                      ),
                    ),
                    Text(
                      widget.tournament.game,
                      maxLines: 1,
                      softWrap: false,
                      style: _t(11, FontWeight.w400, _muted, h: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        widget.walletChip ?? _DefaultWalletChip(balance: _bal, loot: loot),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final t = widget.tournament;
    final loot = t.isLoot;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        14 + mq.padding.top,
                        14,
                        170 + mq.padding.bottom,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _header(context, loot),
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: DetailHero(t: t),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: DetailFacts(t: t),
                          ),
                          DetailInfoGroups(t: t),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          JoinDock(
            t: t,
            balance: _bal,
            gameOk: _gameOk,
            joined: _joined,
            loot: loot,
            onBrowse: widget.onBrowseTournaments,
            onViewMatches: widget.onViewMatches,
            onAdd: () => _sheet.currentState?.open(SheetMode.add),
            onJoin: _onJoinTap,
          ),
          JoinSheet(
            key: _sheet,
            t: t,
            balance: _bal,
            loot: loot,
            toast: _showToast,
            onLoadSlots: widget.onLoadSlots,
            onJoin: widget.onJoin,
            onPay: widget.onPay,
            onOpenProfile: widget.onOpenProfile,
            onBalance: (b) {
              if (mounted) setState(() => _bal = b);
            },
            onJoined: _onJoinedDone,
          ),
          DetailToast(key: _toast),
        ],
      ),
    );
  }
}

/// Default header chip (home-style green glass; gold border for loot).
class _DefaultWalletChip extends StatelessWidget {
  const _DefaultWalletChip({required this.balance, required this.loot});
  final int balance;
  final bool loot;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width <= 480;
    final box = compact ? 28.0 : 34.0;
    return _Surface(
      r: 16,
      color: _c(10, 16, 15, .5),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(255, 255, 255, .16),
          Color.fromRGBO(255, 255, 255, .05),
        ],
      ),
      border: loot ? _c(247, 215, 116, .45) : _c(255, 255, 255, .18),
      blur: 22,
      padding: EdgeInsets.all(compact ? 6 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: box,
            height: box,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: loot ? _c(247, 215, 116, .12) : _c(76, 201, 170, .16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _icon(
              _icWallet,
              loot ? '#f7d774' : '#6ee6c3',
              compact ? 16 : 19,
            ),
          ),
          SizedBox(width: compact ? 5 : 8),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              '₹ ${_inr(balance)}',
              style: _t(compact ? 13 : 15, FontWeight.w700, _white),
            ),
          ),
        ],
      ),
    );
  }
}
