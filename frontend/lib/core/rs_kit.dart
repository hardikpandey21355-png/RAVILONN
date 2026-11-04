import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Home-page kit. Self-contained on purpose (does not import ui_kit.dart),
/// so nothing in your login/legal code can break. `kRsEase` == --ease of the web.

const Curve kRsEase = Cubic(.22, .8, .3, 1);

// ---- palette (index.html :root + common.css values) -------------------------
const Color kRsG1 = Color(0xFF4CC9AA);
const Color kRsG2 = Color(0xFF6EE6C3);
const Color kRsGd = Color(0xFF1B6F5C);
// common.css vars (not attached): adjust here if they differ on the web
const Color kRsRed = Color(0xFFEF4444);
const Color kRsGold = Color(0xFFFBBF24);
const Color kRsBlue = Color(0xFF60A5FA);
const Color kRsCyan = Color(0xFF22D3EE);
const Color kRsMuted = Color(0xFF9FB0AA);
const Color kRsAmber = Color(0xFFF59E0B);

Color rsC(int r, int g, int b, [double a = 1]) => Color.fromRGBO(r, g, b, a);
Color rsW(double a) => Color.fromRGBO(255, 255, 255, a);
Color rsK(double a) => Color.fromRGBO(0, 0, 0, a);

// ---- helpers ---------------------------------------------------------------
bool rsReduce(BuildContext c) => MediaQuery.of(c).disableAnimations;
double rsClamp(double lo, double v, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);
double rsFluid(BuildContext c, double min, double vw, double max) =>
    rsClamp(min, MediaQuery.of(c).size.width * vw / 100, max);
double rsRad(double deg) => deg * math.pi / 180;

/// phase 0..1 of an infinite CSS animation that starts after [delay] seconds
double rsPhase(double s, double delay, double dur) =>
    s < delay ? 0 : ((s - delay) % dur) / dur;
double rsTri(double p) => p < .5 ? p * 2 : (1 - p) * 2;

TextStyle rsT(
  double size, {
  FontWeight w = FontWeight.w400,
  Color color = Colors.white,
  double? ls,
  double? h,
  bool italic = false,
  bool tabular = false,
  List<Shadow>? shadows,
}) => GoogleFonts.poppins(
  fontSize: size,
  fontWeight: w,
  color: color,
  letterSpacing: ls,
  height: h,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  shadows: shadows,
);

// ---- icons (exact paths of _icons.html) ------------------------------------
const Map<String, String> kRsIcons = {
  'wallet':
      '<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16" cy="14" r="1"/>',
  'plus': '<path d="M12 5v14M5 12h14"/>',
  'crown': '<path d="M3 8l4 4 5-7 5 7 4-4-2 11H5z"/>',
  'trophy':
      '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>',
  'ticket':
      '<path d="M3 9a2 2 0 0 0 0 6v3h18v-3a2 2 0 0 1 0-6V6H3z"/><path d="M13 6v12" stroke-dasharray="2 2"/>',
  'users':
      '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6.5 6.5 0 0 1 3.5 6"/>',
  'arrow': '<path d="M9 5l7 7-7 7"/>',
  'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  'gamepad':
      '<rect x="2" y="7" width="20" height="11" rx="5"/><path d="M7 10v4M5 12h4M16 11h.01M18 13h.01"/>',
  'home':
      '<path d="M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
  'swords':
      '<path d="M4 4l9 9M20 4l-9 9M3 21l4-4M21 21l-4-4M8 16l-3 3M16 16l3 3"/>',
  'user': '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  'flame':
      '<path d="M12 3c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z"/>',
  'v': '<path d="M3 5l9 14 9-14M8 5l4 7"/>',
  'back': '<path d="M19 12H5M11 6l-6 6 6 6"/>',
  'search': '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
  'check': '<path d="M5 12l5 5 9-10"/>',
  'lock':
      '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  'copy':
      '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/>',
};

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
double _alpha(Color c) => ((c.toARGB32() >> 24) & 0xFF) / 255.0;

String rsIconSvg(
  String name,
  Color color, {
  bool filled = false,
  double stroke = 2,
}) {
  final h = _hex(color);
  final a = _alpha(color);
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="${filled ? h : 'none'}" fill-opacity="$a" stroke="$h" stroke-opacity="$a" '
      'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">${kRsIcons[name]}</svg>';
}

class RsIcon extends StatelessWidget {
  const RsIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.color = Colors.white,
    this.filled = false,
    this.stroke = 2,
  });
  final String name;
  final double size;
  final Color color;
  final bool filled;
  final double stroke;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    rsIconSvg(name, color, filled: filled, stroke: stroke),
    width: size,
    height: size,
  );
}

// ---- press (scale on tap, like :active{transform:scale(.93)}) ---------------
class RsPress extends StatefulWidget {
  const RsPress({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .95,
    this.duration = const Duration(milliseconds: 200),
    this.enabled = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final bool enabled;
  @override
  State<RsPress> createState() => _RsPressState();
}

class _RsPressState extends State<RsPress> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.enabled ? widget.onTap : null,
    onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
    onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
    onTapCancel: widget.enabled ? () => setState(() => _down = false) : null,
    child: AnimatedScale(
      scale: _down && widget.enabled ? widget.scale : 1,
      duration: rsReduce(context) ? Duration.zero : widget.duration,
      curve: Curves.easeInOutCubic,
      child: widget.child,
    ),
  );
}

// ---- glass -----------------------------------------------------------------
class RsTopLight extends StatelessWidget {
  const RsTopLight({
    super.key,
    required this.radius,
    required this.alpha,
    this.child,
  });
  final double radius;
  final double alpha;
  final Widget? child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: _TopLight(radius, alpha), child: child);
}

class _TopLight extends CustomPainter {
  _TopLight(this.radius, this.alpha);
  final double radius;
  final double alpha;
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(radius, math.min(size.width, size.height) / 2);
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    final a = Path()..addRRect(rr);
    final b = Path()..addRRect(rr.shift(const Offset(0, 1)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, a, b),
      Paint()..color = rsW(alpha),
    );
  }

  @override
  bool shouldRepaint(_TopLight o) => o.radius != radius || o.alpha != alpha;
}

class _OuterShadow extends CustomPainter {
  _OuterShadow(this.radius, this.shadows);
  final double radius;
  final List<BoxShadow> shadows;
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(radius, math.min(size.width, size.height) / 2);
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    final outer = Path()
      ..addRect(Rect.fromLTWH(-300, -300, size.width + 600, size.height + 600));
    final hole = Path()..addRRect(rr);
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, outer, hole));
    for (final s in shadows) {
      canvas.drawRRect(
        rr.shift(s.offset).inflate(s.spreadRadius),
        Paint()
          ..color = s.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadow o) =>
      o.radius != radius || o.shadows != shadows;
}

class _Border extends CustomPainter {
  _Border(this.radius, this.color, this.width);
  final double radius;
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(radius, math.min(size.width, size.height) / 2);
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    ).deflate(width / 2);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_Border o) =>
      o.radius != radius || o.color != color || o.width != width;
}

/// frosted glass: [base] colour, [gradient] on top of it, backdrop [blur],
/// 1px [border], shadows drawn OUTSIDE only (like CSS box-shadow) and an
/// inset top highlight ([topLight] = alpha of `inset 0 1px 0 rgba(255,255,255,a)`).
class RsGlass extends StatelessWidget {
  const RsGlass({
    super.key,
    required this.radius,
    this.blur = 0,
    this.base,
    this.gradient,
    this.border,
    this.borderWidth = 1,
    this.shadows = const [],
    this.topLight = 0,
    this.padding,
    this.child,
  });
  final double radius;
  final double blur;
  final Color? base;
  final Gradient? gradient;
  final Color? border;
  final double borderWidth;
  final List<BoxShadow> shadows;
  final double topLight;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget body = child ?? const SizedBox.shrink();
    if (padding != null) body = Padding(padding: padding!, child: body);
    if (gradient != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: body,
      );
    }
    if (base != null) {
      body = DecoratedBox(
        decoration: BoxDecoration(color: base),
        child: body,
      );
    }
    if (topLight > 0) {
      body = RsTopLight(radius: radius, alpha: topLight, child: body);
    }
    if (blur > 0) {
      body = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: body,
      );
    }
    body = ClipRRect(borderRadius: BorderRadius.circular(radius), child: body);
    return CustomPaint(
      painter: shadows.isEmpty ? null : _OuterShadow(radius, shadows),
      foregroundPainter: border == null
          ? null
          : _Border(radius, border!, borderWidth),
      child: body,
    );
  }
}

/// the shared "glass button" gradient (join / join-lg)
LinearGradient rsBtnGradient() => LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [rsW(.24), rsW(.07)],
);

// ---- entrance (rise / fade / blur) -----------------------------------------
class RsIn extends StatefulWidget {
  const RsIn({
    super.key,
    required this.child,
    this.delay = 0,
    this.dur = .6,
    this.dy = 18,
    this.fromScale = 1,
    this.blur = 0,
    this.curve = kRsEase,
  });
  final Widget child;
  final double delay; // seconds
  final double dur; // seconds
  final double dy;
  final double fromScale;
  final double blur; // start sigma, 0 = no blur layer
  final Curve curve;
  @override
  State<RsIn> createState() => _RsInState();
}

class _RsInState extends State<RsIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _t;
  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.dur;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (total * 1000).round()),
    )..forward();
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(widget.delay / total, 1.0, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (rsReduce(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        Widget w = child!;
        if (widget.blur > 0) {
          final s = widget.blur * (1 - t);
          w = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: s, sigmaY: s),
            child: w,
          );
        }
        w = Transform.translate(
          offset: Offset(0, (1 - t) * widget.dy),
          child: Transform.scale(
            scale: widget.fromScale + (1 - widget.fromScale) * t,
            child: w,
          ),
        );
        return Opacity(opacity: t.clamp(0.0, 1.0), child: w);
      },
    );
  }
}

// ---- infinite loop clock (seconds since mounted) -----------------------------
class RsLoop extends StatefulWidget {
  const RsLoop({super.key, required this.builder});
  final Widget Function(BuildContext context, double seconds) builder;
  @override
  State<RsLoop> createState() => _RsLoopState();
}

class _RsLoopState extends State<RsLoop> with SingleTickerProviderStateMixin {
  late final Ticker _tk;
  final ValueNotifier<double> _s = ValueNotifier<double>(0);
  Duration _lastFrame = Duration.zero;
  @override
  void initState() {
    super.initState();
    _tk = createTicker((elapsed) {
      if (elapsed - _lastFrame < const Duration(milliseconds: 33)) return;
      _lastFrame = elapsed;
      _s.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _tk.dispose();
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frozen = rsReduce(context);
    return ValueListenableBuilder<double>(
      valueListenable: _s,
      builder: (c, v, _) => widget.builder(c, frozen ? 0 : v),
    );
  }
}

/// moving glass shine (`@keyframes shine`, 3.5s): put inside a clipped Stack
class RsShine extends StatelessWidget {
  const RsShine({super.key, this.widthFactor = .3, this.alpha = .35});
  final double widthFactor;
  final double alpha;
  @override
  Widget build(BuildContext context) {
    if (rsReduce(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: RsLoop(
        builder: (c, s) {
          final p = rsPhase(s, 0, 3.5);
          final t = p < .55 ? Curves.easeInOut.transform(p / .55) : 1.0;
          return LayoutBuilder(
            builder: (c, box) {
              final w = box.maxWidth;
              final left = -.6 * w + 1.9 * w * t;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: w * widthFactor,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.skewX(rsRad(-20)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: const Alignment(-1, -.17),
                            end: const Alignment(1, .17),
                            colors: [rsW(0), rsW(alpha), rsW(0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---- image with safe fallback ------------------------------------------------
class RsImage extends StatelessWidget {
  const RsImage(this.name, {super.key, this.alignment = Alignment.center});
  final String name;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) {
    final path = 'assets/images/$name';
    return Image.asset(
      path,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) {
        debugPrint('Image error: $path');
        return const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF15221F), Color(0xFF050807)],
            ),
          ),
          child: SizedBox.expand(),
        );
      },
    );
  }
}

/// 16s slow zoom of the loot / rewards banners (`lootZoom`, alternate)
class RsZoomImage extends StatelessWidget {
  const RsZoomImage(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => RsLoop(
    builder: (c, s) {
      final p = (s / 16) % 2;
      final t = Curves.easeInOut.transform(p <= 1 ? p : 2 - p);
      return Transform.scale(scale: 1 + .09 * t, child: RsImage(name));
    },
  );
}

/// 0.0-1.0 gold gradient text (FREE ENTRY) etc. helper: gradient shifted by [pos]
Shader rsShiftShader(
  Rect bounds,
  List<Color> colors,
  List<double> stops,
  double widthFactor,
  double pos,
) {
  final w = bounds.width;
  final left = bounds.left + (w - w * widthFactor) * pos;
  return LinearGradient(colors: colors, stops: stops).createShader(
    Rect.fromLTWH(left, bounds.top, w * widthFactor, bounds.height),
  );
}
