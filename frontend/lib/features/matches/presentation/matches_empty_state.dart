import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/rs_kit.dart';

TextStyle _t(
  double size,
  FontWeight w,
  Color color, {
  double ls = 0,
  double? h,
}) => GoogleFonts.spaceGrotesk(
  fontSize: size,
  fontWeight: w,
  color: color,
  letterSpacing: ls,
  height: h,
);
Widget _icon(
  String path,
  String colorHex,
  double size, {
  double stroke = 2,
}) => SvgPicture.string(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$colorHex" '
  'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$path</svg>',
  width: size,
  height: size,
);

const String _pArrow = r'<path d="M9 5l7 7-7 7"/>';

/// Thin light line along the top edge: the website's "inset 0 1px 0" highlight.
class _Surface extends StatelessWidget {
  const _Surface({
    this.decoration,
    this.glow = 0,
    this.radius = 0,
    required this.child,
  });
  final BoxDecoration? decoration;
  final double glow, radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (glow > 0)
          Positioned(
            top: 0,
            left: radius * .6,
            right: radius * .6,
            height: 1,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rsC(255, 255, 255, 0),
                      rsC(255, 255, 255, glow),
                      rsC(255, 255, 255, glow),
                      rsC(255, 255, 255, 0),
                    ],
                    stops: const [0, .12, .88, 1],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return decoration == null
        ? stack
        : DecoratedBox(decoration: decoration!, child: stack);
  }
}

/// Empty list: crossed swords.
class MatchesEmptyState extends StatelessWidget {
  const MatchesEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBrowse,
  });
  final String title, subtitle;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 36, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rsC(76, 201, 170, .1),
              border: Border.all(color: rsC(110, 230, 195, .26)),
            ),
            child: const _Swords(size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _t(17, FontWeight.w700, Colors.white),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: _t(12, FontWeight.w400, rsC(154, 168, 163), h: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: _BrowseButton(onTap: onBrowse),
          ),
        ],
      ),
    );
  }
}

class _BrowseButton extends StatelessWidget {
  const _BrowseButton({this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return RsPress(
      scale: .93,
      onTap: onTap ?? () {},
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: _Surface(
          radius: 23,
          glow: .26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            color: rsC(12, 22, 20, .45),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [rsC(110, 230, 195, .26), rsC(27, 111, 92, .2)],
            ),
            border: Border.all(color: rsC(140, 240, 210, .38)),
            boxShadow: [
              BoxShadow(
                color: rsC(0, 0, 0, .35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Browse tournaments',
                  style: _t(13, FontWeight.w600, rsC(234, 255, 247)),
                ),
                const SizedBox(width: 6),
                _icon(_pArrow, '#eafff7', 15),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Swords extends StatelessWidget {
  const _Swords({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return _icon(
      r'<path d="M4 4l9 9M20 4l-9 9M3 21l4-4M21 21l-4-4M8 16l-3 3M16 16l3 3"/>',
      '#6ee6c3',
      size,
    );
  }
}
