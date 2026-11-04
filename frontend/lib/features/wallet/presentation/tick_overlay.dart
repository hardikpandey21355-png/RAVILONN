// lib/features/wallet/presentation/tick_overlay.dart
part of 'wallet_page.dart';

/// Full-screen black success tick. Put it once in a Stack and call
/// `key.currentState?.show()`.
class TickOverlay extends StatefulWidget {
  const TickOverlay({super.key});

  @override
  State<TickOverlay> createState() => TickOverlayState();
}

class TickOverlayState extends State<TickOverlay>
    with TickerProviderStateMixin {
  // fade in .3s, fade out .45s
  late final AnimationController _fade;
  // ring 0-600ms, check 550-950ms, pop 0-500ms
  late final AnimationController _draw;

  Timer? _hideTimer;
  Timer? _removeTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 450),
    );
    _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeTimer?.cancel();
    _fade.dispose();
    _draw.dispose();
    super.dispose();
  }

  void show() {
    _hideTimer?.cancel();
    _removeTimer?.cancel();
    final off = MediaQuery.of(context).disableAnimations;
    setState(() => _visible = true);
    if (off) {
      _fade.value = 1;
      _draw.value = 1;
    } else {
      _fade.forward(from: 0);
      _draw.forward(from: 0);
    }
    _hideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (off) {
        _fade.value = 0;
      } else {
        _fade.reverse();
      }
    });
    _removeTimer = Timer(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Positioned.fill(
      child: FadeTransition(
        opacity: _fade,
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: AnimatedBuilder(
              animation: _draw,
              builder: (context, _) {
                final ms = _draw.value * 950;
                final ring = Curves.ease.transform((ms / 600).clamp(0.0, 1.0));
                final chk = Curves.ease.transform(
                  ((ms - 550) / 400).clamp(0.0, 1.0),
                );
                final pop = kRsEase.transform((ms / 500).clamp(0.0, 1.0));
                return Transform.scale(
                  scale: .6 + .4 * pop,
                  child: CustomPaint(
                    size: const Size(130, 130),
                    painter: _TickPainter(ring, chk),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.ring, this.chk);
  final double ring;
  final double chk;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(50, 50), radius: 45),
        0,
        2 * math.pi * ring,
        false,
        p,
      );
    }
    if (chk > 0) {
      final path = Path()
        ..moveTo(30, 52)
        ..relativeLineTo(14, 14)
        ..relativeLineTo(27, -30);
      final m = path.computeMetrics().first;
      canvas.drawPath(m.extractPath(0, m.length * chk), p);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.ring != ring || old.chk != chk;
}
