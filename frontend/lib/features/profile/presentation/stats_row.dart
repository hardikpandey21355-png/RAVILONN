import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';
import 'profile_group.dart' show ProfileGlass;

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);
Widget _icon(String inner, String hex, double size) => SvgPicture.string(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" '
  'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>',
  width: size,
  height: size,
);

class _Pressable extends StatefulWidget {
  const _Pressable({required this.builder, this.onTap, this.scale = .98});
  final Widget Function(bool down) builder;
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
        child: widget.builder(_down),
      ),
    );
  }
}

const String _swords =
    '<path d="M4 4l9 9M20 4l-9 9M3 21l4-4M21 21l-4-4M8 16l-3 3M16 16l3 3"/>';
const String _trophy =
    '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>';
const String _flame =
    '<path d="M12 3c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z"/>';
const String _wallet =
    '<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16" cy="14" r="1"/>';

class StatsRow extends StatelessWidget {
  const StatsRow({
    super.key,
    this.matches = '0',
    this.wins = '0',
    this.kills = '0',
    this.earned = '₹0',
  });
  final String matches;
  final String wins;
  final String kills;
  final String earned;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            inner: _swords,
            hex: '#22d3ee',
            value: matches,
            label: 'Matches',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            inner: _trophy,
            hex: '#fbbf24',
            value: wins,
            label: 'Wins',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            inner: _flame,
            hex: '#3b82f6',
            value: kills,
            label: 'Kills',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBox(
            inner: _wallet,
            hex: '#fbbf24',
            value: earned,
            label: 'Earned',
            valueColor: _c(110, 230, 195),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.inner,
    required this.hex,
    required this.value,
    required this.label,
    this.valueColor = Colors.white,
  });
  final String inner;
  final String hex;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final vw = MediaQuery.sizeOf(context).width;
    return _Pressable(
      scale: .96,
      onTap: () {},
      builder: (down) => ProfileGlass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        border: down ? _c(110, 230, 195, .4) : _c(255, 255, 255, .14),
        animate: const Duration(milliseconds: 250),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // inline-svg line box (line height of the body text), icon sits at the top
            SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.topCenter,
                child: _icon(inner, hex, 18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: _t((vw * .04).clamp(13.0, 16.0), 700, valueColor),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: _t(9, 400, _c(180, 195, 190)),
            ),
          ],
        ),
      ),
    );
  }
}
