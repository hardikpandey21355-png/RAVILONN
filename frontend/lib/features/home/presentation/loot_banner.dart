import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/rs_kit.dart';

// =============================================================================
// golden padlock (exact paths of the web SVG, viewBox 80 62 140 185)
// =============================================================================
class LockPainter extends CustomPainter {
  LockPainter({
    this.openT = 0,
    this.jiggleDeg = 0,
    this.shineDx,
    this.sparkles = const [1, 1, 1],
    this.shadowBlur = 16,
    this.shadowDy = 10,
    this.shadowAlpha = .6,
  });

  final double openT; // 0 closed .. 1 open (shackle translateY -16, rotate -16deg)
  final double jiggleDeg;
  final double? shineDx; // null = no shine
  final List<double> sparkles; // 0..1 twinkle level per sparkle
  final double shadowBlur;
  final double shadowDy;
  final double shadowAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final sc = size.width / 140;
    canvas.save();
    canvas.scale(sc);
    canvas.translate(-80, -62);

    final shackle = Path()
      ..moveTo(120, 142)
      ..lineTo(120, 108)
      ..arcToPoint(const Offset(180, 108), radius: const Radius.circular(30), clockwise: true)
      ..lineTo(180, 142);
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(95, 140, 110, 95), const Radius.circular(18));

    void withShackle(void Function() draw) {
      canvas.save();
      canvas.translate(120, 142);
      canvas.translate(0, -16 * openT);
      canvas.rotate(rsRad(-16 * openT + jiggleDeg));
      canvas.translate(-120, -142);
      draw();
      canvas.restore();
    }

    // drop-shadow
    if (shadowAlpha > 0) {
      final sig = (shadowBlur / 2) / sc;
      canvas.save();
      canvas.translate(0, shadowDy / sc);
      canvas.drawRRect(
        body,
        Paint()
          ..color = rsK(shadowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sig),
      );
      withShackle(() => canvas.drawPath(
            shackle,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 15
              ..strokeCap = StrokeCap.round
              ..color = rsK(shadowAlpha)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, sig),
          ));
      canvas.restore();
    }

    // shackle
    final sb = const Rect.fromLTRB(120, 78, 180, 142);
    withShackle(() => canvas.drawPath(
          shackle,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 15
            ..strokeCap = StrokeCap.round
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF4F6F5), Color(0xFFAEB6B3), Color(0xFF6B7370)],
              stops: [0, .5, 1],
            ).createShader(sb),
        ));

    // body
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7D774), Color(0xFFD9A21F), Color(0xFF8A5A06)],
          stops: [0, .55, 1],
        ).createShader(const Rect.fromLTWH(95, 140, 110, 95)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(103, 148, 94, 79), const Radius.circular(13)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = rsW(.35),
    );

    // moving shine, clipped to the body
    if (shineDx != null) {
      canvas.save();
      canvas.clipRRect(body);
      canvas.drawRect(Rect.fromLTWH(95 + shineDx!, 130, 24, 120), Paint()..color = rsW(.42));
      canvas.restore();
    }

    // keyhole
    final key = Paint()..color = const Color(0xFF3B2402);
    canvas.drawCircle(const Offset(150, 183), 10, key);
    canvas.drawPath(
      Path()
        ..moveTo(146, 188)
        ..relativeLineTo(8, 0)
        ..relativeLineTo(3, 22)
        ..relativeLineTo(-14, 0)
        ..close(),
      key,
    );

    // sparkles
    void spark(double x, double y, double r, double k, double v) {
      if (v <= 0) return;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(.3 + .7 * v);
      final p = Path()
        ..moveTo(0, -r)
        ..lineTo(k, -k)
        ..lineTo(r, 0)
        ..lineTo(k, k)
        ..lineTo(0, r)
        ..lineTo(-k, k)
        ..lineTo(-r, 0)
        ..lineTo(-k, -k)
        ..close();
      canvas.drawPath(p, Paint()..color = Color.fromRGBO(255, 247, 214, v.clamp(0.0, 1.0)));
      canvas.restore();
    }

    spark(205, 100, 9, 2.2, sparkles[0]);
    spark(92, 150, 7, 1.7, sparkles[1]);
    spark(196, 215, 6, 1.5, sparkles[2]);

    canvas.restore();
  }

  @override
  bool shouldRepaint(LockPainter o) => true;
}

double _kf(List<List<double>> k, double p) {
  for (int i = 0; i < k.length - 1; i++) {
    if (p <= k[i + 1][0]) {
      final t = (p - k[i][0]) / (k[i + 1][0] - k[i][0]);
      return k[i][1] + (k[i + 1][1] - k[i][1]) * Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    }
  }
  return k.last[1];
}

/// animated lock: float, shackle jiggle, shine sweep, twinkling sparkles; [open] on Sunday
class RsLock extends StatelessWidget {
  const RsLock({super.key, required this.width, required this.open});
  final double width;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final reduce = rsReduce(context);
    final h = width * 185 / 140;
    return RsLoop(builder: (c, s) {
      final e = Curves.easeInOut.transform(rsTri(((s / 4.5) % 1)));
      final jiggle = _kf(const [
        [0, 0],
        [.72, 0],
        [.76, -4],
        [.80, 3],
        [.84, -2],
        [.88, 0],
        [1, 0],
      ], (s / 5.5) % 1);
      final sp = ((s / 4) % 1);
      final shine = sp < .5 ? -140 + 340 * Curves.easeInOut.transform(sp / .5) : 200.0;
      double spk(int i) {
        if (reduce) return 1;
        final d = i * 1.0;
        if (s < d) return 0;
        return Curves.easeInOut.transform(rsTri(((s - d) % 3) / 3));
      }

      return TweenAnimationBuilder<double>(
        tween: Tween<double>(end: open ? 1 : 0),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 800),
        curve: kRsEase,
        builder: (context, openT, _) {
          final painter = LockPainter(
            openT: openT,
            jiggleDeg: open || reduce ? 0 : jiggle,
            shineDx: reduce ? null : shine,
            sparkles: [spk(0), spk(1), spk(2)],
          );
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(0.0, reduce ? 0.0 : -7 * e)
              ..rotateZ(reduce ? 0.0 : rsRad(-1.5 + 3 * e)),
            child: SizedBox(width: width, height: h, child: CustomPaint(painter: painter)),
          );
        },
      );
    });
  }
}

// =============================================================================
// LOOT TOURNAMENTS banner
// =============================================================================
class _LootInfo {
  const _LootInfo(this.open, this.secs);
  final bool open;
  final int secs;
}

class LootBanner extends StatefulWidget {
  const LootBanner({super.key});
  @override
  State<LootBanner> createState() => _LootBannerState();
}

class _LootBannerState extends State<LootBanner> {
  final GlobalKey _lockKey = GlobalKey();
  late final ValueNotifier<_LootInfo> _info = ValueNotifier(_calc());
  Timer? _timer;
  OverlayEntry? _entry;
  bool _playing = false;
  bool _hideLock = false;

  /// IST: Sunday 12:00 AM countdown (on Sunday: until Monday 12:00 AM)
  static _LootInfo _calc() {
    final n = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final day = n.weekday % 7; // 0 = Sunday
    final midnight = DateTime.utc(n.year, n.month, n.day);
    final open = day == 0;
    final target = open
        ? midnight.add(const Duration(days: 1))
        : midnight.add(Duration(days: (7 - day) % 7));
    final s = target.difference(n).inSeconds;
    return _LootInfo(open, s < 0 ? 0 : s);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _info.value = _calc());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entry?.remove();
    _info.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_playing) return;
    final nav = Navigator.of(context);
    if (rsReduce(context)) {
      nav.pushNamed('/loot');
      return;
    }
    final ro = _lockKey.currentContext?.findRenderObject();
    if (ro is! RenderBox) {
      nav.pushNamed('/loot');
      return;
    }
    _playing = true;
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    setState(() => _hideLock = true);
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Cinematic(
        rect: rect,
        onDone: () async {
          final f = nav.pushNamed('/loot');
          await Future<void>.delayed(const Duration(milliseconds: 120));
          entry.remove();
          _entry = null;
          await f;
          if (mounted) {
            setState(() {
              _hideLock = false;
              _playing = false;
            });
          }
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return RsPress(
      scale: .97,
      onTap: _tap,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: RsGlass(
          radius: 26,
          base: const Color(0xFF050807),
          shadows: [BoxShadow(color: rsK(.5), blurRadius: 40, offset: const Offset(0, 16))],
          child: Stack(
            children: [
              const Positioned.fill(child: RsZoomImage('loot_banner.jpg')),
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: ValueListenableBuilder<_LootInfo>(
                  valueListenable: _info,
                  builder: (context, info, _) {
                    final s = info.secs;
                    final vals = [
                      (p2(s ~/ 86400), 'DAYS'),
                      (p2(s % 86400 ~/ 3600), 'HRS'),
                      (p2(s % 3600 ~/ 60), 'MIN'),
                      (p2(s % 60), 'SEC'),
                    ];
                    return Row(
                      children: [
                        Expanded(
                          flex: 13,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _info_(context, info, vals),
                          ),
                        ),
                        Expanded(
                          flex: 7,
                          child: Center(
                            child: LayoutBuilder(builder: (context, box) {
                              final w = math.min(box.maxWidth * .86, 150.0);
                              return Opacity(
                                opacity: _hideLock ? 0 : 1,
                                child: SizedBox(
                                  key: _lockKey,
                                  width: w,
                                  height: w * 185 / 140,
                                  child: OverflowBox(
                                    maxWidth: w * 2,
                                    maxHeight: w * 2,
                                    child: RsLock(width: w, open: info.open),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info_(BuildContext context, _LootInfo info, List<(String, String)> vals) {
    final boxW = rsFluid(context, 38, 11.5, 50);
    final fs = rsFluid(context, 9, 2.8, 11);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LOOT\nTOURNAMENTS',
          style: rsT(rsFluid(context, 17, 5.6, 25),
              w: FontWeight.w700, ls: rsFluid(context, 17, 5.6, 25) * .03, h: 1.02, shadows: [
            Shadow(color: rsK(.7), blurRadius: 16, offset: const Offset(0, 2)),
          ]),
        ),
        const SizedBox(height: 7),
        _FreeEntry(fs: fs),
        const SizedBox(height: 9),
        Text(
          info.open ? 'OPEN NOW • ENDS IN' : 'OPENS IN',
          style: rsT(9, ls: 9 * .22, color: const Color(0xFF9FE9D0)),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < vals.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              SizedBox(
                width: boxW,
                child: RsGlass(
                  radius: 12,
                  blur: 14,
                  base: rsW(.1),
                  topLight: .14,
                  padding: const EdgeInsets.only(top: 6, bottom: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vals[i].$1,
                        style: rsT(rsFluid(context, 14, 4.4, 18),
                            w: FontWeight.w700, h: 1.1, color: const Color(0xFFD8FFF1), tabular: true),
                      ),
                      Text(vals[i].$2, style: rsT(7, ls: 7 * .12, color: const Color(0xFFA9B6B1))),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// "— FREE ENTRY —": gold stamped text with lines on both sides and a moving shine
class _FreeEntry extends StatelessWidget {
  const _FreeEntry({required this.fs});
  final double fs;
  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Container(
          width: 16,
          height: 1.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: left
                  ? const [Color(0x00F7D774), Color(0xFFF7D774)]
                  : const [Color(0xFFF7D774), Color(0x00F7D774)],
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        const SizedBox(width: 7),
        RsLoop(builder: (c, s) {
          final p = rsPhase(s, 0, 3.4);
          final pos = p < .6 ? 1 - Curves.easeInOut.transform(p / .6) : 0.0;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (b) => rsShiftShader(
              b,
              const [Color(0xFFC98A12), Color(0xFFF7D774), Color(0xFFFFF7D6), Color(0xFFF7D774), Color(0xFFC98A12)],
              const [0, .35, .5, .65, 1],
              2.5,
              pos,
            ),
            child: Text('FREE ENTRY', style: rsT(fs, w: FontWeight.w800, italic: true, ls: fs * .3)),
          );
        }),
        const SizedBox(width: 7),
        line(false),
      ],
    );
  }
}

// =============================================================================
// unlock cinematic: lock flies to centre, shakes, glow + rays, white flash, then /loot
// =============================================================================
class _Cinematic extends StatefulWidget {
  const _Cinematic({required this.rect, required this.onDone});
  final Rect rect;
  final VoidCallback onDone;
  @override
  State<_Cinematic> createState() => _CinematicState();
}

class _CinematicState extends State<_Cinematic> with TickerProviderStateMixin {
  late final AnimationController _dim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _grow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final AnimationController _rays = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  static const Curve _moveCurve = Cubic(.22, .9, .25, 1);
  static const Curve _raysCurve = Cubic(.2, .7, .3, 1);

  bool _started = false;
  late double _cx, _cy, _s;
  late Size _screen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _screen = MediaQuery.of(context).size;
    final r = widget.rect;
    _cx = _screen.width / 2 - (r.left + r.width / 2);
    _cy = _screen.height / 2 - (r.top + r.height / 2);
    _s = math.min(_screen.width * .5, 260) / r.width;
    _run();
  }

  Future<void> _run() async {
    try {
      _dim.forward();
      await _move.forward().orCancel;
      await _shake.forward().orCancel;
      _grow.forward();
      await _rays.forward().orCancel;
      await _flash.forward().orCancel;
    } catch (_) {}
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    for (final c in [_dim, _move, _shake, _grow, _rays, _flash]) {
      c.dispose();
    }
    super.dispose();
  }

  // shake keyframes (34 steps, linear, amplitude grows)
  ({double x, double y, double sc, double rot}) _frame(int i) {
    const n = 34;
    final k = i / n;
    final amp = 2 + k * 11;
    final sgn = i.isOdd ? 1.0 : -1.0;
    return (
      x: _cx + sgn * amp,
      y: _cy + ((i % 3) - 1) * amp * .35,
      sc: _s * (1 + k * .06),
      rot: sgn * amp * .45,
    );
  }

  Matrix4 _cloneMatrix() {
    double x = 0, y = 0, sc = 1, rot = 0;
    if (_grow.value > 0) {
      final g = Curves.easeOut.transform(_grow.value);
      x = _cx;
      y = _cy;
      sc = _s * 1.06 + (_s * 1.22 - _s * 1.06) * g;
    } else if (_shake.value > 0) {
      const n = 34;
      final f = _shake.value * n;
      final i = math.min(f.floor(), n - 1);
      final a = _frame(i), b = _frame(i + 1);
      final t = f - i;
      x = a.x + (b.x - a.x) * t;
      y = a.y + (b.y - a.y) * t;
      sc = a.sc + (b.sc - a.sc) * t;
      rot = a.rot + (b.rot - a.rot) * t;
    } else {
      final m = _moveCurve.transform(_move.value);
      x = _cx * m;
      y = _cy * m;
      sc = 1 + (_s - 1) * m;
    }
    return Matrix4.identity()
      ..translate(x, y)
      ..scale(sc)
      ..rotateZ(rsRad(rot));
  }

  @override
  Widget build(BuildContext context) {
    final vmin = math.min(_screen.width, _screen.height);
    return AbsorbPointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_dim, _move, _shake, _grow, _rays, _flash]),
        builder: (context, _) {
          // glow core
          double coreOp = 0, coreSc = .5;
          if (_grow.value > 0) {
            final g = Curves.easeOut.transform(_grow.value);
            coreOp = .9 + .1 * g;
            coreSc = 1 + 1.2 * g;
          } else if (_shake.value > 0) {
            final g = Curves.easeIn.transform(_shake.value);
            coreOp = .9 * g;
            coreSc = .5 + .5 * g;
          }
          // rays
          double rOp = 0, rSc = .2, rRot = 0;
          if (_rays.value > 0) {
            final v = _rays.value;
            if (v < .4) {
              final u = _raysCurve.transform(v / .4);
              rOp = u;
              rSc = .2 + .7 * u;
              rRot = 25 * u;
            } else {
              final u = _raysCurve.transform((v - .4) / .6);
              rOp = 1;
              rSc = .9 + .5 * u;
              rRot = 25 + 35 * u;
            }
          }
          final r = widget.rect;
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: rsK(.88 * Curves.easeOut.transform(_dim.value))),
              if (rOp > 0)
                Opacity(
                  opacity: rOp.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..scale(rSc)
                      ..rotateZ(rsRad(rRot)),
                    child: CustomPaint(painter: _RaysPainter(), size: Size.infinite),
                  ),
                ),
              if (coreOp > 0)
                Center(
                  child: Opacity(
                    opacity: coreOp.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: coreSc,
                      child: SizedBox(
                        width: vmin * .46,
                        height: vmin * .46,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              radius: .7071,
                              colors: [
                                Color.fromRGBO(255, 247, 214, .95),
                                Color.fromRGBO(247, 215, 116, .45),
                                Color.fromRGBO(247, 215, 116, 0),
                              ],
                              stops: [0, .4, .7],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: r.left,
                top: r.top,
                width: r.width,
                height: r.height,
                child: Transform(
                  alignment: Alignment.center,
                  transform: _cloneMatrix(),
                  child: CustomPaint(
                    // the web clone has no CSS animations: closed shackle, static, sparkles on
                    painter: LockPainter(shadowBlur: 22, shadowDy: 10, shadowAlpha: .7),
                  ),
                ),
              ),
              ColoredBox(color: rsW(Curves.easeIn.transform(_flash.value))),
            ],
          );
        },
      ),
    );
  }
}

/// repeating-conic-gradient(rgba(255,233,163,.6) 0 3deg, transparent 3deg 12deg) with radial mask
class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final vmax = math.max(size.width, size.height) / 100;
    final r0 = 120.2 * vmax; // farthest-corner of the 170vmax square
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        c,
        r0,
        const [Color.fromRGBO(255, 233, 163, .6), Color.fromRGBO(255, 233, 163, .36), Color.fromRGBO(255, 233, 163, 0)],
        const [0, .18, .55],
      );
    final rect = Rect.fromCircle(center: c, radius: r0 * .56);
    for (int k = 0; k < 30; k++) {
      final start = rsRad(k * 12.0 - 90);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..arcTo(rect, start, rsRad(3), false)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RaysPainter o) => false;
}