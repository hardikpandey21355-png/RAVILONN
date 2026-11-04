import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/rs_kit.dart';
import '../data/tournaments_mock.dart';

// The card and upcoming box share page-specific visual helpers through `part`.
part 'tournament_card.dart';
part 'upcoming_more_box.dart';

List<TournamentCard> visibleTournamentItems({
  required List<TournamentCard> items,
  required String tab,
  required String query,
  required Set<String> joined,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final visible = items.where((item) {
    final includedStatus = switch (tab) {
      'live' => item.status == 'live',
      'upcoming' => item.status == 'upcoming',
      _ => item.status == 'live' || item.status == 'upcoming',
    };
    return includedStatus &&
        (normalizedQuery.isEmpty ||
            '${item.mode} ${item.detail} free fire'.toLowerCase().contains(
              normalizedQuery,
            ));
  }).toList();
  visible.sort((a, b) {
    final statusOrder =
        (a.status == 'live' ? 0 : 1) - (b.status == 'live' ? 0 : 1);
    if (statusOrder != 0) return statusOrder;
    final joinedOrder =
        (joined.contains(a.id) ? 0 : 1) - (joined.contains(b.id) ? 0 : 1);
    if (joinedOrder != 0) return joinedOrder;
    final timerOrder = a.secs.compareTo(b.secs);
    return timerOrder != 0 ? timerOrder : a.id.compareTo(b.id);
  });
  return visible;
}

// ============================================================================
// Page-specific helpers preserve the standalone tournament design.
// ============================================================================

TextStyle _t(
  double size,
  FontWeight weight,
  Color color, {
  double? ls,
  double? h,
}) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: ls,
  height: h,
);

Duration _d(BuildContext context, int ms) =>
    rsReduce(context) ? Duration.zero : Duration(milliseconds: ms);

String _clock(int s) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(s ~/ 3600)}:${p((s % 3600) ~/ 60)}:${p(s % 60)}';
}

// ---- CSS-style linear gradient (angle in degrees, like linear-gradient(145deg, ...)) ----
class _CssAngle extends GradientTransform {
  const _CssAngle(this.deg);
  final double deg;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final w = bounds.width, h = bounds.height;
    if (w == 0) return null;
    final a = deg * math.pi / 180;
    final len = (w * math.sin(a)).abs() + (h * math.cos(a)).abs();
    final c = bounds.center;
    return Matrix4.translationValues(c.dx, c.dy, 0) *
        Matrix4.rotationZ(a - math.pi / 2) *
        Matrix4.diagonal3Values(len / w, 1, 1) *
        Matrix4.translationValues(-c.dx, -c.dy, 0);
  }
}

LinearGradient _g(double deg, List<Color> colors, [List<double>? stops]) =>
    LinearGradient(colors: colors, stops: stops, transform: _CssAngle(deg));

// ---- shared green glass look (--gbtn) ----
final LinearGradient _gbtnGrad = _g(180, [
  rsC(110, 230, 195, .26),
  rsC(27, 111, 92, .2),
]);
final Color _gbtnColor = rsC(12, 22, 20, .45);
final Color _gbtnBorder = rsC(140, 240, 210, .38);

// ---- glass pieces ----
class _Sh {
  const _Sh(this.dx, this.dy, this.blur, this.color, [this.spread = 0]);
  final double dx, dy, blur, spread;
  final Color color;
}

/// CSS-like outer box-shadow: drawn only OUTSIDE the box (a Flutter BoxShadow would show through glass).
class _ShadowPainter extends CustomPainter {
  _ShadowPainter(this.radius, this.shadows);
  final double radius;
  final List<_Sh> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final r = math.min(radius, size.shortestSide / 2);
    final box = Offset.zero & size;
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(box.inflate(1000))
      ..addRRect(RRect.fromRectAndRadius(box, Radius.circular(r)));
    canvas.save();
    canvas.clipPath(outside);
    for (final s in shadows) {
      final shape = RRect.fromRectAndRadius(
        box.shift(Offset(s.dx, s.dy)).inflate(s.spread),
        Radius.circular(r + s.spread),
      );
      final paint = Paint()..color = s.color;
      if (s.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      }
      canvas.drawRRect(shape, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.radius != radius || old.shadows != shadows;
}

/// CSS `inset 0 1px 0 color`: a 1px highlight on the inside of the top edge.
class _InsetPainter extends CustomPainter {
  _InsetPainter(this.radius, this.color);
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.max(math.min(radius, size.shortestSide / 2), 0.0);
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );
    final band = Path.combine(
      PathOperation.difference,
      Path()..addRRect(rrect),
      Path()..addRRect(rrect.shift(const Offset(0, 1))),
    );
    canvas.drawPath(band, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InsetPainter old) =>
      old.radius != radius || old.color != color;
}

List<double> _satMatrix(double s) => <double>[
  .213 + .787 * s,
  .715 - .715 * s,
  .072 - .072 * s,
  0,
  0,
  .213 - .213 * s,
  .715 + .285 * s,
  .072 - .072 * s,
  0,
  0,
  .213 - .213 * s,
  .715 - .715 * s,
  .072 + .928 * s,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

final ui.ColorFilter _saturate140 = ui.ColorFilter.matrix(_satMatrix(1.4));

ui.ImageFilter _blur(double sigma, bool saturate) {
  final b = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  return saturate ? ui.ImageFilter.compose(outer: _saturate140, inner: b) : b;
}

/// Frosted glass: backdrop blur + (optional) saturate, tinted background, 1px border,
/// inset top highlight and outside-only drop shadow.
class _Glass extends StatelessWidget {
  const _Glass({
    this.width,
    this.height,
    this.radius = 999,
    this.color,
    this.gradient,
    this.border = const Color.fromRGBO(255, 255, 255, .14),
    this.blur = 4,
    this.saturate = false,
    this.inset,
    this.shadows = const <_Sh>[],
    this.alignment,
    this.padding,
    this.clipInner = false,
    this.child,
  });

  final double? width, height;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final Color border;
  final double blur;
  final bool saturate;
  final Color? inset;
  final List<_Sh> shadows;
  final AlignmentGeometry? alignment;
  final EdgeInsetsGeometry? padding;
  final bool clipInner;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget body = child ?? const SizedBox.shrink();
    if (clipInner) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(math.max(radius - 1, 0)),
        child: body,
      );
    }
    if (alignment != null || padding != null) {
      body = Container(alignment: alignment, padding: padding, child: body);
    }
    final r = BorderRadius.circular(radius);
    Widget glass = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: r,
        border: Border.all(color: border),
      ),
      child: inset == null
          ? body
          : CustomPaint(
              painter: _InsetPainter(radius - 1, inset!),
              child: body,
            ),
    );
    glass = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(filter: _blur(blur, saturate), child: glass),
    );
    return CustomPaint(painter: _ShadowPainter(radius, shadows), child: glass);
  }
}

/// Tap with a smooth squeeze (like :active { transform: scale(...) }).
class _Pressable extends StatefulWidget {
  const _Pressable({
    this.onTap,
    this.scale = .98,
    this.ms = 300,
    this.child,
    this.builder,
  }) : assert(child != null || builder != null);

  final VoidCallback? onTap;
  final double scale;
  final int ms;
  final Widget? child;
  final Widget Function(BuildContext context, bool pressed)? builder;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final inner = widget.builder != null
        ? widget.builder!(context, _down)
        : widget.child!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _d(context, widget.ms),
        curve: kRsEase,
        child: inner,
      ),
    );
  }
}

/// "rise" animation: opacity 0->1 and translateY 18->0.
class _Rise extends StatelessWidget {
  const _Rise({required this.anim, required this.child});
  final Animation<double> anim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, ch) {
        final v = anim.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - v)),
            child: ch,
          ),
        );
      },
    );
  }
}

/// Plays the rise animation by itself when it first appears (cards, "Upcoming" box).
class _RiseOnMount extends StatefulWidget {
  const _RiseOnMount({required this.delay, required this.child});
  final double delay; // seconds
  final Widget child;

  @override
  State<_RiseOnMount> createState() => _RiseOnMountState();
}

class _RiseOnMountState extends State<_RiseOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + .6;
    _ctl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (total * 1000).round()),
    );
    _anim = CurvedAnimation(
      parent: _ctl,
      curve: Interval(widget.delay / total, 1.0, curve: kRsEase),
    );
    _ctl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _ctl.value = 1;
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Rise(anim: _anim, child: widget.child);
}

/// White 6px dot that blinks (1.2s) inside the LIVE tag.
class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: .3,
      ).chain(CurveTween(curve: Curves.ease)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: .3,
        end: 1,
      ).chain(CurveTween(curve: Curves.ease)),
      weight: 50,
    ),
  ]).animate(_ctl);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.stop();
      _ctl.value = 0;
    } else if (!_ctl.isAnimating) {
      _ctl.repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ============================================================================
// The page
// ============================================================================

class TournamentsPage extends StatefulWidget {
  const TournamentsPage({
    super.key,
    required this.walletChip,
    this.onBack,
    this.onOpen,
    required this.joinedIds,
    this.items,
    this.bottomInset = const EdgeInsets.only(bottom: 100),
  });

  /// Shared wallet widget shown at the right of the header.
  final Widget walletChip;

  /// Back button tap.
  final VoidCallback? onBack;

  /// Tap on a card or on "Join Now" (not for live cards).
  final void Function(String id)? onOpen;

  /// Shared ids of joined tournaments.
  final ValueListenable<Set<String>> joinedIds;

  /// The app supplies Firestore-backed items; null is treated as an empty list.
  final List<TournamentCard>? items;

  /// Space at the bottom (for your bottom navigation).
  final EdgeInsets bottomInset;

  @override
  State<TournamentsPage> createState() => _TournamentsPageState();
}

class _TournamentsPageState extends State<TournamentsPage>
    with SingleTickerProviderStateMixin {
  static const EdgeInsets _h = EdgeInsets.symmetric(horizontal: 14);
  static const List<String> _tabKeys = <String>['all', 'live', 'upcoming'];
  static const List<String> _tabLabels = <String>['All', 'Live', 'Upcoming'];

  late List<TournamentCard> _items;

  late final AnimationController _intro;
  late final List<Animation<double>> _blocks;
  late Map<String, ValueNotifier<int>> _secs;
  final TextEditingController _search = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _timer;

  String _tab = 'all';
  String _q = '';

  @override
  void initState() {
    super.initState();
    _items = widget.items ?? const <TournamentCard>[];
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )..forward();
    _blocks = <Animation<double>>[
      for (final d in const <double>[.02, .07, .12, .17, .22])
        CurvedAnimation(
          parent: _intro,
          curve: Interval(
            d / .82,
            math.min(1.0, (d + .6) / .82),
            curve: kRsEase,
          ),
        ),
    ];
    _secs = {for (final c in _items) c.id: ValueNotifier<int>(c.secs)};
    // one timer for every card: counts down 1 second at a time, stops at 0
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final n in _secs.values) {
        if (n.value > 0) n.value--;
      }
    });
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant TournamentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      final previous = _secs;
      _items = widget.items ?? const <TournamentCard>[];
      _secs = <String, ValueNotifier<int>>{
        for (final item in _items)
          item.id: previous.remove(item.id) ?? ValueNotifier<int>(item.secs),
      };
      for (final notifier in previous.values) {
        notifier.dispose();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _intro.value = 1;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _search.dispose();
    _focus.dispose();
    for (final n in _secs.values) {
      n.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: Colors.black,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(top: 14) + widget.bottomInset,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Rise(
                      anim: _blocks[0],
                      child: Padding(padding: _h, child: _header(w)),
                    ),
                    const SizedBox(height: 16),
                    _Rise(
                      anim: _blocks[1],
                      child: Padding(padding: _h, child: _searchBox()),
                    ),
                    const SizedBox(height: 14),
                    _Rise(anim: _blocks[2], child: _chips()),
                    const SizedBox(height: 12),
                    _Rise(
                      anim: _blocks[3],
                      child: Padding(padding: _h, child: _tabsRow()),
                    ),
                    const SizedBox(height: 16),
                    _Rise(
                      anim: _blocks[4],
                      child: Padding(padding: _h, child: _list()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ header
  Widget _header(double w) {
    final titleSize = (w * .05).clamp(18.0, 22.0).toDouble();
    final shadow = <Shadow>[
      Shadow(
        color: rsC(0, 0, 0, .5),
        offset: const Offset(0, 1),
        blurRadius: 14,
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (w > 380) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onBack,
                  child: Semantics(
                    button: true,
                    label: 'Back to home',
                    child: _Glass(
                      width: 38,
                      height: 38,
                      radius: 19,
                      gradient: _g(135, [
                        rsC(255, 255, 255, .14),
                        rsC(255, 255, 255, .04),
                      ]),
                      border: rsC(255, 255, 255, .22),
                      blur: 4,
                      saturate: false,
                      inset: rsC(255, 255, 255, .25),
                      shadows: [_Sh(0, 6, 20, rsC(0, 0, 0, .35))],
                      alignment: Alignment.center,
                      child: const RsIcon('back', size: 20, stroke: 1.8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tournaments',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(
                        titleSize,
                        FontWeight.w700,
                        Colors.white,
                        h: 1.15,
                      ).copyWith(shadows: shadow),
                    ),
                    Text(
                      'Compete • Win • Earn',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: _t(
                        11,
                        FontWeight.w400,
                        rsC(156, 163, 199),
                      ).copyWith(shadows: shadow),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        widget.walletChip,
      ],
    );
  }

  // ------------------------------------------------------------ search
  Widget _searchBox() {
    final focused = _focus.hasFocus;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: focused ? 1 : 0),
      duration: _d(context, 300),
      curve: Curves.ease,
      builder: (context, t, _) {
        return _Glass(
          height: 50,
          radius: 999,
          color: rsC(255, 255, 255, .06),
          border: Color.lerp(
            rsC(255, 255, 255, .14),
            rsC(76, 201, 170, .7),
            t,
          )!,
          blur: 4,
          inset: rsC(255, 255, 255, .1),
          shadows: [_Sh(0, 0, 0, rsC(47, 143, 122, .25 * t), 3)],
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const RsIcon(
                'search',
                size: 20,
                color: Color(0xFFB9CBC5),
                stroke: 1.8,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _focus,
                  cursorColor: Colors.white,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  style: _t(16, FontWeight.w400, Colors.white),
                  decoration: InputDecoration.collapsed(
                    hintText: 'Search tournaments...',
                    hintStyle: _t(16, FontWeight.w400, rsC(169, 182, 177)),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ game chips
  Widget _chips() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
        child: Row(
          children: [
            RsPress(
              scale: .93,
              child: _Glass(
                height: 44,
                radius: 999,
                gradient: _gbtnGrad,
                color: _gbtnColor,
                border: _gbtnBorder,
                blur: 4,
                inset: rsC(255, 255, 255, .26),
                shadows: [_Sh(0, 6, 18, rsC(0, 0, 0, .35))],
                padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rsC(239, 68, 68, .18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const RsIcon(
                        'flame',
                        size: 17,
                        color: Color(0xFFEF4444),
                        filled: true,
                        stroke: 1.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Free Fire',
                      style: _t(13, FontWeight.w500, rsC(234, 255, 247)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ status tabs
  Widget _tabsRow() {
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _TabBtn(
              kind: _tabKeys[i],
              label: _tabLabels[i],
              selected: _tab == _tabKeys[i],
              onTap: () => setState(() => _tab = _tabKeys[i]),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ list
  Widget _list() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: widget.joinedIds,
      builder: (context, joined, _) {
        final filtered = visibleTournamentItems(
          items: _items,
          tab: _tab,
          query: _q,
          joined: joined,
        );

        final kids = <Widget>[];
        void add(String key, Widget w) {
          kids.add(
            Padding(
              key: ValueKey<String>(key),
              padding: EdgeInsets.only(top: kids.isEmpty ? 0 : 12),
              child: w,
            ),
          );
        }

        const delays = <double>[.08, .14, .2, .26, .3];
        var ci = 0;
        Widget card(TournamentCard c, bool isJoined) {
          final delay = delays[math.min(ci, delays.length - 1)];
          ci++;
          return _RiseOnMount(
            delay: delay,
            child: TournamentCardView(
              card: c,
              secs: _secs[c.id]!,
              joined: isJoined,
              onOpen: () => widget.onOpen?.call(c.id),
            ),
          );
        }

        final statuses = _tab == 'all'
            ? const <String>['live', 'upcoming']
            : <String>[_tab];
        for (final status in statuses) {
          final statusItems = filtered
              .where((item) => item.status == status)
              .toList();
          final joinedItems = statusItems
              .where((item) => joined.contains(item.id))
              .toList();
          final otherItems = statusItems
              .where((item) => !joined.contains(item.id))
              .toList();

          if (joinedItems.isNotEmpty) {
            add(
              'head_joined_$status',
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                child: Row(
                  children: [
                    const RsIcon(
                      'check',
                      size: 15,
                      color: Color(0xFF4ADE80),
                      stroke: 1.8,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Joined matches (${joinedItems.length})',
                      style: _t(13, FontWeight.w600, rsC(74, 222, 128)),
                    ),
                  ],
                ),
              ),
            );
            for (final item in joinedItems) {
              add('card_${item.id}', card(item, true));
            }
          }
          if (joinedItems.isNotEmpty && otherItems.isNotEmpty) {
            add(
              'head_more_$status',
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                child: Text(
                  'More tournaments',
                  style: _t(13, FontWeight.w600, rsC(196, 211, 206)),
                ),
              ),
            );
          }
          for (final item in otherItems) {
            add('card_${item.id}', card(item, false));
          }
        }
        if (filtered.isEmpty) {
          add(
            'empty',
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
              child: Text(
                'No tournaments found',
                textAlign: TextAlign.center,
                style: _t(13, FontWeight.w400, rsC(154, 168, 163)),
              ),
            ),
          );
        }
        if (_tab != 'live') {
          add(
            'more_box',
            const _RiseOnMount(delay: 0, child: UpcomingMoreBox()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kids,
        );
      },
    );
  }
}

// ============================================================================
// Small private widgets
// ============================================================================

/// One status tab: All / Live / Upcoming.
class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.kind,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String kind;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RsPress(
      scale: .93,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: _d(context, 400),
        curve: Curves.ease,
        builder: (context, t, _) {
          final text = Color.lerp(rsC(195, 208, 203), rsC(234, 255, 247), t)!;
          return _Glass(
            height: 46,
            radius: 999,
            color: Color.lerp(
              rsC(255, 255, 255, .06),
              rsC(12, 22, 20, .45),
              t,
            )!,
            gradient: _g(180, [
              rsC(110, 230, 195, .26 * t),
              rsC(27, 111, 92, .2 * t),
            ]),
            border: Color.lerp(
              rsC(255, 255, 255, .14),
              rsC(140, 240, 210, .38),
              t,
            )!,
            blur: 4,
            inset: Color.lerp(
              rsC(255, 255, 255, .1),
              rsC(255, 255, 255, .26),
              t,
            )!,
            shadows: [_Sh(0, 6, 18, rsC(0, 0, 0, .35 * t))],
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind == 'live')
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (kind == 'upcoming')
                  RsIcon('clock', size: 16, color: text, stroke: 1.8),
                if (kind != 'all') const SizedBox(width: 7),
                Text(label, style: _t(13, FontWeight.w500, text)),
              ],
            ),
          );
        },
      ),
    );
  }
}
