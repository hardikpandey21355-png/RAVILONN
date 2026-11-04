import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/rs_kit.dart';

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(
  double size,
  FontWeight w,
  Color color, {
  double ls = 0,
  double? h,
}) => rsT(size, w: w, color: color, ls: ls, h: h);

const Color _goldTxt = Color(0xFFFFE9A3);
const Color _panel = Color(0xFF0F0C05);
const Color _soft = Color(0xFFA89C78);
const Color _edge = Color.fromRGBO(247, 215, 116, .5);

/// Dashed rounded border (CSS: border:1.5px dashed).
class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 1.5;
    const dash = 6.0;
    const gap = 4.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        width / 2,
        width / 2,
        size.width - width,
        size.height - width,
      ),
      Radius.circular(radius - width / 2),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    for (final m in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

/// "Match coming soon" placeholder (shown for every missing match out of 2).
class LootSoonCard extends StatelessWidget {
  const LootSoonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: const _DashedRRectPainter(
        color: Color.fromRGBO(247, 215, 116, .55),
        radius: 22,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 140),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _panel,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _c(247, 215, 116, .09),
                _c(247, 215, 116, .02),
                _c(247, 215, 116, .02),
              ],
              stops: const [0, .55, 1],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _c(247, 215, 116, .08),
                  border: Border.all(color: _edge),
                ),
                child: const RsIcon('lock', size: 21, color: Color(0xFFF7D774)),
              ),
              const SizedBox(height: 8),
              Text(
                'Match coming soon',
                textAlign: TextAlign.center,
                style: _t(15, FontWeight.w700, _goldTxt),
              ),
              Text(
                'This free match will be announced soon',
                textAlign: TextAlign.center,
                style: _t(11, FontWeight.w400, _soft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
