part of 'tournaments_page.dart';

/// The "Upcoming" box at the end of the list: slow liquid blobs, film grain, dashed border.
class UpcomingMoreBox extends StatefulWidget {
  const UpcomingMoreBox({
    super.key,
    this.text = 'More Free Fire tournaments are coming soon',
  });

  final String text;

  @override
  State<UpcomingMoreBox> createState() => _UpcomingMoreBoxState();
}

class _Blob {
  const _Blob(
    this.w,
    this.h,
    this.color, {
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.ms,
    required this.tx,
    required this.ty,
    required this.s,
  });

  final double w, h; // size as a fraction of the box
  final Color color;
  final double? left, right, top, bottom; // position as a fraction of the box
  final int ms; // one way duration
  final double tx, ty, s; // end translate (fraction of own size) and scale
}

class _UpcomingMoreBoxState extends State<UpcomingMoreBox>
    with TickerProviderStateMixin {
  static const List<_Blob> _blobs = <_Blob>[
    _Blob(
      .55,
      .70,
      Color.fromRGBO(240, 236, 208, .9),
      left: -.12,
      top: -.22,
      ms: 6000,
      tx: .55,
      ty: .40,
      s: 1.25,
    ),
    _Blob(
      .48,
      .80,
      Color(0xFF05060D),
      left: .08,
      top: .40,
      ms: 7500,
      tx: .70,
      ty: -.35,
      s: 1.15,
    ),
    _Blob(
      .42,
      .60,
      Color.fromRGBO(214, 210, 186, .65),
      left: .38,
      top: -.10,
      ms: 8500,
      tx: -.45,
      ty: .60,
      s: 1.30,
    ),
    _Blob(
      .50,
      .85,
      Color(0xFF04050C),
      right: -.14,
      top: -.05,
      ms: 7000,
      tx: -.60,
      ty: .30,
      s: .90,
    ),
    _Blob(
      .46,
      .48,
      Color.fromRGBO(244, 240, 214, .95),
      right: -.08,
      bottom: -.18,
      ms: 8000,
      tx: -.70,
      ty: -.30,
      s: 1.20,
    ),
  ];

  late final List<AnimationController> _ctls = <AnimationController>[
    for (final b in _blobs)
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: b.ms),
      ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final off = MediaQuery.disableAnimationsOf(context);
    for (final c in _ctls) {
      if (off) {
        c.stop();
        c.value = 0;
      } else if (!c.isAnimating) {
        c.repeat(reverse: true); // "alternate" like the CSS
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadow = <Shadow>[
      Shadow(
        color: rsC(0, 0, 0, .85),
        offset: const Offset(0, 2),
        blurRadius: 14,
      ),
    ];
    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: rsC(27, 28, 27),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: _fluid(),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Glass(
                      width: 46,
                      height: 46,
                      radius: 23,
                      color: rsC(0, 0, 0, .35),
                      border: rsC(255, 255, 255, .35),
                      blur: 10,
                      saturate: false,
                      alignment: Alignment.center,
                      child: const RsIcon(
                        'clock',
                        size: 24,
                        color: Color(0xFFF4F0D6),
                        stroke: 1.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upcoming',
                      style: _t(
                        20,
                        FontWeight.w700,
                        Colors.white,
                      ).copyWith(shadows: shadow),
                    ),
                    const SizedBox(height: 2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        widget.text,
                        textAlign: TextAlign.center,
                        style: _t(
                          12,
                          FontWeight.w400,
                          rsC(228, 225, 207),
                        ).copyWith(shadows: shadow),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DashedRRectPainter(
                  radius: 26,
                  color: rsC(255, 255, 255, .28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fluid() {
    return LayoutBuilder(
      builder: (context, bc) {
        final w = bc.maxWidth, h = bc.maxHeight;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: ColoredBox(color: rsC(43, 44, 42))),
            for (var i = 0; i < _blobs.length; i++) _blob(i, w, h),
            const Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _GrainPainter()),
              ),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: _DarkEllipsePainter()),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(int i, double w, double h) {
    final b = _blobs[i];
    final bw = w * b.w, bh = h * b.h;
    final left = b.left != null ? w * b.left! : w * (1 - b.right!) - bw;
    final top = b.top != null ? h * b.top! : h * (1 - b.bottom!) - bh;
    return Positioned(
      left: left,
      top: top,
      width: bw,
      height: bh,
      child: AnimatedBuilder(
        animation: _ctls[i],
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: ClipOval(child: ColoredBox(color: b.color)),
        ),
        builder: (context, child) {
          final v = Curves.easeInOut.transform(_ctls[i].value);
          final s = 1 + (b.s - 1) * v;
          return Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.translationValues(b.tx * bw * v, b.ty * bh * v, 0) *
                Matrix4.diagonal3Values(s, s, 1),
            child: child,
          );
        },
      ),
    );
  }
}

/// radial-gradient(ellipse at center, black .55, black .15 75%) so the text stays readable.
class _DarkEllipsePainter extends CustomPainter {
  const _DarkEllipsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = size.center(Offset.zero);
    final rx = size.width / 2 * math.sqrt2;
    final ry = size.height / 2 * math.sqrt2;
    final m =
        Matrix4.translationValues(c.dx, c.dy, 0) *
        Matrix4.diagonal3Values(1, ry / rx, 1) *
        Matrix4.translationValues(-c.dx, -c.dy, 0);
    final shader = ui.Gradient.radial(
      c,
      rx,
      [rsC(0, 0, 0, .55), rsC(0, 0, 0, .15)],
      const [0, .75],
      ui.TileMode.clamp,
      m.storage,
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_DarkEllipsePainter old) => false;
}

/// Film grain: random white specks blended with "overlay" at 35% opacity.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rnd = math.Random(7);
    final count = (size.width * size.height / 14).round();
    const alphas = <double>[.25, .5, .8];
    for (final a in alphas) {
      final n = count ~/ alphas.length;
      final pts = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        pts[i * 2] = rnd.nextDouble() * size.width;
        pts[i * 2 + 1] = rnd.nextDouble() * size.height;
      }
      final paint = Paint()
        ..blendMode = BlendMode.overlay
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.square
        ..color = rsC(255, 255, 255, a * .35);
      canvas.drawRawPoints(ui.PointMode.points, pts, paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}

/// 1px dashed rounded border.
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.radius, required this.color});

  final double radius;
  final Color color;
  final double dash = 3;
  final double gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.5);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius - .5)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.dash != dash ||
      old.gap != gap;
}
