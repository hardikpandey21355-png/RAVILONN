import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared UI helpers (login_page.dart ke private helpers ke public versions).
Color c(int r, int g, int b, [double o = 1]) => Color.fromRGBO(r, g, b, o);

TextStyle t(double size, FontWeight w, Color color, {double? ls, double? h}) =>
    GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: w,
      color: color,
      letterSpacing: ls,
      height: h,
    );

const Cubic kEase = Cubic(.22, .8, .3, 1);

String svgString(String inner, String color, {double sw = 1.8}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$color" '
    'stroke-width="$sw" stroke-linecap="round" stroke-linejoin="round">$inner</svg>';

Widget svgIcon(String inner, String color, double size) =>
    SvgPicture.string(svgString(inner, color), width: size, height: size);

/// Button/card press: smooth squeeze
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = .96,
    this.duration = const Duration(milliseconds: 200),
  });
  final VoidCallback? onTap;
  final Widget child;
  final double scale;
  final Duration duration;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: widget.duration,
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}
