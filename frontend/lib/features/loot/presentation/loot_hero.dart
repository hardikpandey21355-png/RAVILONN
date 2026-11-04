import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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

const Color _gold = Color(0xFFF7D774);
const Color _gold2 = Color(0xFFD9A21F);
const Color _goldTxt = Color(0xFFFFE9A3);
const Color _ink = Color(0xFF3B2402);
const Color _panel = Color(0xFF0F0C05);
const Color _mute = Color(0xFF8D92B8);
const Color _edge = Color.fromRGBO(247, 215, 116, .5);

/// Draws the 2px gold top border that follows the rounded corners (CSS: border-top:2px solid gold).
class _GoldTopPainter extends CustomPainter {
  const _GoldTopPainter(this.r);
  final double r;

  @override
  void paint(Canvas canvas, Size s) {
    final rr = r - 1;
    final path = Path()
      ..arcTo(
        Rect.fromCircle(center: Offset(r, r), radius: rr),
        5 * math.pi / 4,
        math.pi / 4,
        true,
      )
      ..lineTo(s.width - r, 1)
      ..arcTo(
        Rect.fromCircle(center: Offset(s.width - r, r), radius: rr),
        3 * math.pi / 2,
        math.pi / 4,
        false,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _gold,
    );
  }

  @override
  bool shouldRepaint(_GoldTopPainter old) => old.r != r;
}

/// The "gold box" of the page: warm black, soft gold gradient on top, 1px gold border and a 2px gold top line.
/// Used by the hero and by the match cards. [clip] = overflow hidden.
class LootGoldBox extends StatelessWidget {
  const LootGoldBox({
    super.key,
    required this.radius,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.clip = false,
  });
  final double radius;
  final Widget child;
  final EdgeInsets padding;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    Widget inner = Padding(padding: padding, child: child);
    if (clip) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: inner,
      );
    }
    return CustomPaint(
      foregroundPainter: _GoldTopPainter(radius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
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
          border: Border.all(color: _edge),
        ),
        child: inner,
      ),
    );
  }
}

// ===================================================================== HERO
class LootHero extends StatelessWidget {
  const LootHero({super.key});

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: _c(247, 215, 116, .1),
      border: Border.all(color: _c(247, 215, 116, .45)),
    ),
    child: Text(t, style: _t(10, FontWeight.w700, _gold, ls: 1)),
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h2 = (w * .09).clamp(28.0, 36.0).toDouble();
    final base = _t(13, FontWeight.w400, _mute, h: 1.7);
    final bold = _t(13, FontWeight.w600, _goldTxt, h: 1.7);
    return LootGoldBox(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_gold2, _gold, Color(0xFFFFF0B0)],
                stops: [0, .55, 1],
              ),
            ),
            child: Text(
              'FREE ENTRY',
              style: _t(11, FontWeight.w800, _ink, ls: 2.64),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'LOOT\nTOURNAMENTS',
            style: _t(h2, FontWeight.w800, _gold, ls: .04 * h2, h: 1.05),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: base,
              children: [
                const TextSpan(text: 'Loot matches are free for players, '),
                TextSpan(text: 'no entry fee', style: bold),
                const TextSpan(text: '. They run only on '),
                TextSpan(text: 'Sunday', style: bold),
                const TextSpan(text: ', and the rewards are real.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_chip('NO FEE'), _chip('REAL CASH'), _chip('2 MATCHES')],
          ),
        ],
      ),
    );
  }
}

// ===================================================================== NOTICE
/// Red "play 1 paid match" pill, or the gold "Unlocked" pill.
class LootNotice extends StatelessWidget {
  const LootNotice({super.key, required this.paidOk});
  final bool paidOk;

  @override
  Widget build(BuildContext context) {
    if (paidOk) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _c(247, 215, 116, .1),
          border: Border.all(color: _c(247, 215, 116, .5)),
        ),
        child: Text(
          'Unlocked: tumne is hafte paid tournament khela hai, ab free matches join kar sakte ho.',
          textAlign: TextAlign.center,
          style: _t(12, FontWeight.w600, _goldTxt),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _c(0, 0, 0, .35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _c(28, 10, 10, .45),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_c(248, 113, 113, .3), _c(153, 27, 27, .24)],
                  ),
                  border: Border.all(color: _c(252, 165, 165, .4)),
                ),
                child: Text(
                  'To join Loot matches you must play at least 1 paid tournament every week.',
                  textAlign: TextAlign.center,
                  style: _t(
                    12,
                    FontWeight.w600,
                    const Color(0xFFFFE4E4),
                    h: 1.5,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 18,
                right: 18,
                height: 1,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _c(255, 255, 255, 0),
                          _c(255, 255, 255, .26),
                          _c(255, 255, 255, .26),
                          _c(255, 255, 255, 0),
                        ],
                        stops: const [0, .12, .88, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
