import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';

const String _defs = '''<defs>
<linearGradient id="swMetal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".5" stop-color="#c9cecc"/><stop offset="1" stop-color="#8a918f"/></linearGradient>
<linearGradient id="swBladeL" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#dfe3e1"/></linearGradient>
<linearGradient id="swBladeR" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#b4bab8"/><stop offset="1" stop-color="#7b8280"/></linearGradient>
</defs>''';

const String _shape = '''<path d="M-3.8 26 L0 26 L0 80 L-2.4 70 Z" fill="url(#swBladeL)"/>
<path d="M0 26 L3.8 26 L2.4 70 L0 80 Z" fill="url(#swBladeR)"/>
<path d="M-9 22 Q-9 20.5 -7.5 20.5 H7.5 Q9 20.5 9 22 V24 Q9 25.5 7.5 25.5 H-7.5 Q-9 25.5 -9 24 Z" fill="url(#swMetal)"/>
<circle cx="-9" cy="22.8" r="2" fill="url(#swMetal)"/><circle cx="9" cy="22.8" r="2" fill="url(#swMetal)"/>
<rect x="-2" y="8" width="4" height="12.6" rx="1" fill="#cfd3d1"/>
<path d="M-2 10 L2 12 M-2 13 L2 15 M-2 16 L2 18" stroke="#5d6462" stroke-width=".9" fill="none"/>
<circle cx="0" cy="4" r="4.2" fill="url(#swMetal)" stroke="#5d6462" stroke-width=".6"/>
<circle cx="0" cy="4" r="1.6" fill="#4b5250"/>''';

String _swordSvg(double tx, double rot) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 92">$_defs<g transform="translate($tx 8) rotate($rot)">$_shape</g></svg>';

const String _sparkSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 92"><g stroke="#ffffff" stroke-width="1.6" stroke-linecap="round" fill="none"><path d="M50 35v4M50 47v4M42 43h4M54 43h4M44.5 37.5l2.8 2.8M55.5 37.5l-2.8 2.8"/></g></svg>';

/// circular swords badge: swords drop in, white spark burst, diagonal shine every ~4.6s
class SwordsBadge extends StatefulWidget {
  const SwordsBadge({super.key});
  @override
  State<SwordsBadge> createState() => _SwordsBadgeState();
}

class _SwordsBadgeState extends State<SwordsBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final Widget _left = SvgPicture.string(_swordSvg(27, -33));
  final Widget _right = SvgPicture.string(_swordSvg(73, 33));
  final Widget _spark = SvgPicture.string(_sparkSvg);
  static const Curve _swCurve = Cubic(.3, 1.35, .5, 1);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1650))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _sword(double sec) => _swCurve.transform(((sec - .2) / 1.2).clamp(0.0, 1.0));

  // spark: 0-35% fade/scale in, 35-100% out (ease-out per segment)
  (double, double) _sparkVals(double sec) {
    final t = ((sec - .95) / .7).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return (0, .3);
    if (t < .35) {
      final u = Curves.easeOut.transform(t / .35);
      return (u, .3 + .8 * u);
    }
    final u = Curves.easeOut.transform((t - .35) / .65);
    return (1 - u, 1.1 + .6 * u);
  }

  @override
  Widget build(BuildContext context) {
    final size = rsFluid(context, 54, 15, 64);
    final reduce = rsReduce(context);
    final boxW = size * .8;
    final boxH = boxW * .92;
    final u = boxW / 100;

    Widget sword(Widget svg, double ox, double sign, double sec) {
      final e = reduce ? 1.0 : _sword(sec);
      return Opacity(
        opacity: e.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment((ox - 50) / 50, (8 - 46) / 46),
          transform: Matrix4.identity()
            ..translate(0.0, -9 * (1 - e) * u)
            ..rotateZ(sign * rsRad(42) * (1 - e)),
          child: svg,
        ),
      );
    }

    return RsIn(
      delay: .05,
      dur: .9,
      dy: 0,
      fromScale: .6,
      blur: 6,
      child: SizedBox(
        width: size,
        height: size,
        child: RsTopLight(
          radius: size / 2,
          alpha: .22,
          child: ClipOval(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.5),
                  radius: .901,
                  colors: [Color.fromRGBO(76, 201, 170, .2), Color.fromRGBO(10, 16, 15, .9)],
                  stops: [0, .72],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: boxW,
                    height: boxH,
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) {
                        final sec = _c.value * 1.65;
                        final sp = reduce ? (0.0, .3) : _sparkVals(sec);
                        return Stack(children: [
                          Positioned.fill(child: sword(_left, 27, 1, sec)),
                          Positioned.fill(child: sword(_right, 73, -1, sec)),
                          if (sp.$1 > 0)
                            Positioned.fill(
                              child: Opacity(
                                opacity: sp.$1.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: sp.$2,
                                  alignment: Alignment(0, (43 - 46) / 46),
                                  child: _spark,
                                ),
                              ),
                            ),
                        ]);
                      },
                    ),
                  ),
                  if (!reduce)
                    RsLoop(builder: (c, s) {
                      // ::after inset -25%, translateX(-130% -> 130%), 4.6s, delay 1.9s
                      final p = rsPhase(s, 1.9, 4.6);
                      final t = p < .32 ? Curves.easeInOut.transform(p / .32) : 1.0;
                      final dx = (-1.3 + 2.6 * t) * size * 1.5;
                      return Positioned(
                        left: -size * .25 + dx,
                        top: -size * .25,
                        width: size * 1.5,
                        height: size * 1.5,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: const Alignment(-.906, -.423),
                                end: const Alignment(.906, .423),
                                colors: [rsW(0), rsW(.32), rsW(0)],
                                stops: const [.4, .5, .6],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Play • Compete • Win": words fade in with blur, then a white shine keeps sweeping
class Tagline extends StatelessWidget {
  const Tagline({super.key});
  static const _words = ['Play', '•', 'Compete', '•', 'Win'];

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.of(context).size.width <= 480;
    final fs = small ? 10.0 : 12.0;
    final gap = small ? 4.0 : 7.0;
    final reduce = rsReduce(context);

    Widget word(int i) {
      final style = rsT(fs, w: FontWeight.w500, ls: fs * .04, color: Colors.white);
      if (reduce) {
        return Text(_words[i], style: rsT(fs, w: FontWeight.w500, ls: fs * .04, color: const Color(0xFF9FB0AA)));
      }
      return RsIn(
        delay: .5 + i * .13,
        dur: .8,
        dy: 8,
        blur: 6,
        child: RsLoop(builder: (c, s) {
          final p = rsPhase(s, 2 + i * .12, 4.2);
          final pos = p < .45 ? 1 - Curves.easeInOut.transform(p / .45) : 0.0;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (b) => rsShiftShader(
              b,
              const [Color(0xFF8D9F99), Color(0xFF8D9F99), Colors.white, Color(0xFF8D9F99), Color(0xFF8D9F99)],
              const [0, .42, .5, .58, 1],
              3,
              pos,
            ),
            child: Text(_words[i], style: style),
          );
        }),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _words.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              word(i),
            ],
          ],
        ),
      ),
    );
  }
}