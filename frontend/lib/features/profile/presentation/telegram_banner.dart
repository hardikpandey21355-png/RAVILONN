import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);
Widget _icon(
  String inner,
  String hex,
  double size, {
  String fill = 'none',
  bool noStroke = false,
}) => SvgPicture.string(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$fill" stroke="${noStroke ? 'none' : hex}" '
  'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>',
  width: size,
  height: size,
);

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap, this.scale = .98});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final off = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: off ? Duration.zero : const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}

const String _arrow = '<path d="M9 5l7 7-7 7"/>';
const String _tgPath =
    '<path d="M16.906 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/>';

/// `background-size:240% 100%` + `background-position` 0% -> 100% (alternate), 115deg gradient.
class _Flow extends GradientTransform {
  const _Flow(this.t, this.deg);
  final double t;
  final double deg;
  @override
  Matrix4? transform(Rect b, {TextDirection? textDirection}) {
    final iw = b.width * 2.4;
    final img = Rect.fromLTWH(b.left - 1.4 * b.width * t, b.top, iw, b.height);
    final a = deg * math.pi / 180;
    final len = (iw * math.sin(a)).abs() + (b.height * math.cos(a)).abs();
    final k = b.width == 0 ? 1.0 : len / b.width;
    return Matrix4.translationValues(img.center.dx, img.center.dy, 0) *
        Matrix4.rotationZ(a - math.pi / 2) *
        Matrix4.diagonal3Values(k, 1, 1) *
        Matrix4.translationValues(-b.center.dx, -b.center.dy, 0);
  }
}

class TelegramBanner extends StatefulWidget {
  const TelegramBanner({super.key, this.onTap});
  final VoidCallback? onTap;
  @override
  State<TelegramBanner> createState() => _TelegramBannerState();
}

class _TelegramBannerState extends State<TelegramBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.stop();
      _ctl.value = 0;
    } else if (!_ctl.isAnimating) {
      _ctl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      scale: .96,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_ctl.value);
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _c(140, 215, 255, .5)),
              boxShadow: [
                BoxShadow(
                  color: _c(0, 0, 0, .25),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _c(34, 158, 217, .95),
                  _c(16, 92, 146, .96),
                  _c(42, 171, 238, .92),
                ],
                stops: const [0, .5, 1],
                transform: _Flow(t, 115),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: _icon(
                          _tgPath,
                          '#229ED9',
                          26,
                          fill: '#229ED9',
                          noStroke: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Join RIVALON_OFFICIAL',
                              style: _t(14, 600, Colors.white, h: 1.3),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Match updates, room alerts and offers on Telegram',
                                style: _t(
                                  11,
                                  400,
                                  const Color(0xFFE3F4FF),
                                  h: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _c(255, 255, 255, .4)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _c(255, 255, 255, .28),
                              _c(255, 255, 255, .1),
                            ],
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Join', style: _t(12, 600, Colors.white)),
                                const SizedBox(width: 4),
                                _icon(_arrow, '#ffffff', 13),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 0,
                  height: 1,
                  child: ColoredBox(color: _c(255, 255, 255, .2)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
