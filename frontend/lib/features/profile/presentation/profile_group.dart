// Shared glass pieces for the Profile page: glass box, group card, row, status
// chip, glass switch, buttons, and the bottom-sheet shell used by the 3 sheets.
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);
const Curve _ease = kRsEase;
Widget _icon(
  String inner,
  String hex,
  double size, {
  String fill = 'none',
  bool noStroke = false,
  Color? tint,
}) => SvgPicture.string(
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$fill" stroke="${noStroke ? 'none' : hex}" '
  'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>',
  width: size,
  height: size,
  colorFilter: tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
);

const String _arrow = '<path d="M9 5l7 7-7 7"/>';

class _Pressable extends StatefulWidget {
  const _Pressable({this.child, this.builder, this.onTap, this.scale = .98});
  final Widget? child;
  final Widget Function(bool down)? builder;
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
    final on = widget.onTap != null;
    final off = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => _set(true) : null,
      onTapUp: on ? (_) => _set(false) : null,
      onTapCancel: on ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: off ? Duration.zero : const Duration(milliseconds: 110),
        curve: Curves.easeInOutCubic,
        child: widget.builder != null ? widget.builder!(_down) : widget.child,
      ),
    );
  }
}

/// CSS-style angled gradient (angle in degrees, 180 = top->bottom) that follows the box size.
class _Css extends GradientTransform {
  const _Css(this.deg);
  final double deg;
  @override
  Matrix4? transform(Rect b, {TextDirection? textDirection}) {
    final a = deg * math.pi / 180;
    final len = (b.width * math.sin(a)).abs() + (b.height * math.cos(a)).abs();
    final k = b.width == 0 ? 1.0 : len / b.width;
    final m = b.center;
    return Matrix4.translationValues(m.dx, m.dy, 0) *
        Matrix4.rotationZ(a - math.pi / 2) *
        Matrix4.diagonal3Values(k, 1, 1) *
        Matrix4.translationValues(-m.dx, -m.dy, 0);
  }
}

/// A gradient painted over a solid [base] colour, merged into one gradient.
LinearGradient _grad(
  double deg,
  Color base,
  List<Color> cs,
  List<double>? stops,
) => LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [for (final c in cs) Color.alphaBlend(c, base)],
  stops: stops,
  transform: _Css(deg),
);

// ───────────────────────── glass box ─────────────────────────
class ProfileGlass extends StatelessWidget {
  const ProfileGlass({
    super.key,
    required this.radius,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.base = const Color.fromRGBO(12, 16, 15, .46),
    this.colors = const [
      Color.fromRGBO(255, 255, 255, .15),
      Color.fromRGBO(255, 255, 255, .04),
      Color.fromRGBO(255, 255, 255, .08),
    ],
    this.stops = const [0, .42, 1],
    this.angle = 145,
    this.border = const Color.fromRGBO(255, 255, 255, .14),
    this.sigma = 8,
    this.hl = .16,
    this.shadow = const [
      BoxShadow(
        color: Color.fromRGBO(0, 0, 0, .22),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
    ],
    this.animate = Duration.zero,
  });

  final double radius;
  final Widget child;
  final EdgeInsets padding;
  final Color base;
  final List<Color> colors;
  final List<double> stops;
  final double angle;
  final Color border;
  final double sigma;
  final double hl; // inset top highlight alpha
  final List<BoxShadow> shadow;
  final Duration animate;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final off = MediaQuery.disableAnimationsOf(context);
    Widget box = AnimatedContainer(
      duration: off ? Duration.zero : animate,
      curve: Curves.ease,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: border),
        gradient: _grad(angle, base, colors, stops),
      ),
      child: child,
    );
    if (hl > 0) {
      box = Stack(
        children: [
          box,
          Positioned(
            left: radius * .6,
            right: radius * .6,
            top: 1,
            height: 1,
            child: IgnorePointer(
              child: ColoredBox(color: _c(255, 255, 255, hl)),
            ),
          ),
        ],
      );
    }
    box = ClipRRect(
      borderRadius: r,
      child: sigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: box,
            )
          : box,
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadow),
      child: box,
    );
  }
}

// ───────────────────────── group + row ─────────────────────────
class ProfileGroup extends StatelessWidget {
  const ProfileGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ProfileGlass(
      radius: 24,
      border: _c(255, 255, 255, .16),
      hl: .2,
      shadow: [
        BoxShadow(
          color: _c(0, 0, 0, .28),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 66, right: 16),
                child: Container(height: 1, color: _c(255, 255, 255, .08)),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class ProfileIconBox extends StatelessWidget {
  const ProfileIconBox({
    super.key,
    required this.inner,
    this.size = 38,
    this.radius = 12,
    this.iconSize = 19,
  });
  final String inner;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _c(76, 201, 170, .12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _c(110, 230, 195, .22)),
      ),
      child: _icon(inner, '#6ee6c3', iconSize),
    );
  }
}

class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });
  final String icon; // inner svg of the icon
  final String title;
  final String sub;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final off = MediaQuery.disableAnimationsOf(context);
    Widget content(bool down) => AnimatedContainer(
      duration: off ? Duration.zero : const Duration(milliseconds: 250),
      color: down ? _c(255, 255, 255, .05) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ProfileIconBox(inner: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: _t(13, 500, Colors.white, h: 1.3)),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: _t(11, 400, _c(156, 163, 199)),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (chevron) ...[
            const SizedBox(width: 12),
            _Chevron(down: down, off: off),
          ],
        ],
      ),
    );
    if (onTap == null) return content(false);
    return _Pressable(scale: 1, onTap: onTap, builder: content);
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.down, required this.off});
  final bool down;
  final bool off;
  @override
  Widget build(BuildContext context) {
    final d = off ? Duration.zero : const Duration(milliseconds: 250);
    return AnimatedContainer(
      duration: d,
      curve: _ease,
      transform: Matrix4.translationValues(down ? 3 : 0, 0, 0),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: down ? _c(110, 230, 195) : _c(156, 163, 199)),
        duration: d,
        builder: (_, c, _) => _icon(_arrow, '#9ca3c7', 16, tint: c),
      ),
    );
  }
}

// ───────────────────────── status chip ─────────────────────────
class ProfileStatusChip extends StatelessWidget {
  const ProfileStatusChip({super.key, required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final d = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return AnimatedContainer(
      duration: d,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ok ? _c(76, 201, 170, .16) : _c(251, 191, 36, .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedDefaultTextStyle(
        duration: d,
        style: _t(9, 600, ok ? _c(110, 230, 195) : _c(251, 191, 36)),
        child: Text(label, softWrap: false),
      ),
    );
  }
}

// ───────────────────────── glass switch ─────────────────────────
class ProfileSwitch extends StatelessWidget {
  const ProfileSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final off = MediaQuery.disableAnimationsOf(context);
    final knob = off ? Duration.zero : const Duration(milliseconds: 400);
    final trk = off ? Duration.zero : const Duration(milliseconds: 350);
    final offC = _c(255, 255, 255, .14);
    final onGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        for (final c in [_c(110, 230, 195, .26), _c(27, 111, 92, .2)])
          Color.alphaBlend(c, _c(12, 22, 20, .45)),
      ],
    );
    return Semantics(
      label: label,
      toggled: value,
      child: _Pressable(
        scale: .93,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: trk,
          curve: _ease,
          width: 46,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: value
                ? onGrad
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [offC, offC],
                  ),
            border: Border.all(
              color: value ? _c(140, 240, 210, .38) : _c(255, 255, 255, .14),
            ),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: _c(0, 0, 0, .35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: knob,
                curve: _ease,
                left: value ? 21 : 3,
                top: 3,
                child: AnimatedContainer(
                  duration: trk,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value ? const Color(0xFFEAFFF7) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _c(0, 0, 0, .35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
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

// ───────────────────────── buttons ─────────────────────────
enum ProfileButtonKind { primary, ghost, danger, gameSave, gameEdit }

class _BS {
  const _BS(this.fg, this.border, this.grad, this.sigma, this.hl, this.shadow);
  final Color fg;
  final Color border;
  final LinearGradient grad;
  final double sigma;
  final double hl;
  final List<BoxShadow> shadow;
}

_BS _bs(ProfileButtonKind k) {
  List<BoxShadow> sh(double a) => [
    BoxShadow(
      color: _c(0, 0, 0, a),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
  switch (k) {
    case ProfileButtonKind.primary:
      return _BS(
        _c(234, 255, 247),
        _c(140, 240, 210, .38),
        _grad(180, _c(12, 22, 20, .45), [
          _c(110, 230, 195, .26),
          _c(27, 111, 92, .2),
        ], null),
        18,
        .26,
        sh(.35),
      );
    case ProfileButtonKind.ghost:
      return _BS(
        Colors.white,
        _c(255, 255, 255, .18),
        _grad(180, _c(20, 44, 38, .5), [
          _c(255, 255, 255, .15),
          _c(255, 255, 255, .04),
        ], null),
        18,
        .2,
        sh(.35),
      );
    case ProfileButtonKind.danger:
      return _BS(
        _c(252, 165, 165),
        _c(239, 68, 68, .45),
        _grad(180, Colors.transparent, [
          _c(239, 68, 68, .08),
          _c(239, 68, 68, .08),
        ], null),
        0,
        .06,
        const [],
      );
    case ProfileButtonKind.gameSave:
      return _BS(
        Colors.white,
        _c(255, 255, 255, .22),
        _grad(180, Colors.transparent, [
          const Color(0xFF1A1B1D),
          const Color(0xFF050506),
        ], null),
        0,
        .12,
        sh(.6),
      );
    case ProfileButtonKind.gameEdit:
      return _BS(
        Colors.white,
        _c(255, 255, 255, .35),
        _grad(180, _c(18, 19, 22, .7), [
          _c(255, 255, 255, .26),
          _c(255, 255, 255, .07),
        ], null),
        18,
        .3,
        sh(.45),
      );
  }
}

class ProfileButton extends StatelessWidget {
  const ProfileButton({
    super.key,
    required this.label,
    this.onTap, // null => disabled (50% opacity)
    this.kind = ProfileButtonKind.primary,
    this.height = 50,
    this.iconInner,
  });
  final String label;
  final VoidCallback? onTap;
  final ProfileButtonKind kind;
  final double height;
  final String? iconInner;

  @override
  Widget build(BuildContext context) {
    final s = _bs(kind);
    final off = MediaQuery.disableAnimationsOf(context);
    final r = BorderRadius.circular(999);
    Widget btn = Stack(
      children: [
        AnimatedContainer(
          duration: off ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.ease,
          height: height,
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: s.border),
            gradient: s.grad,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconInner != null) ...[
                _icon(iconInner!, '#ffffff', 16),
                const SizedBox(width: 7),
              ],
              Text(label, style: _t(14, 600, s.fg)),
            ],
          ),
        ),
        Positioned(
          left: height * .5,
          right: height * .5,
          top: 1,
          height: 1,
          child: IgnorePointer(
            child: ColoredBox(color: _c(255, 255, 255, s.hl)),
          ),
        ),
      ],
    );
    final sg = s.sigma > 0 ? s.sigma : .01;
    btn = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sg, sigmaY: sg),
        child: btn,
      ),
    );
    btn = DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: s.shadow),
      child: btn,
    );
    return AnimatedOpacity(
      opacity: onTap == null ? .5 : 1,
      duration: off ? Duration.zero : const Duration(milliseconds: 250),
      child: _Pressable(scale: .93, onTap: onTap, child: btn),
    );
  }
}

// ───────────────────────── bottom sheets ─────────────────────────
/// Modal bottom sheet: black .6 barrier + blur 8, slide up 60px + fade (450ms), Escape / tap outside closes.
Future<T?> showProfileSheet<T>(BuildContext context, WidgetBuilder builder) {
  final off = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.transparent,
    transitionDuration: off ? Duration.zero : const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, _) => Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(ctx).maybePop(),
        },
        child: Focus(autofocus: true, child: builder(ctx)),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final f = const Interval(
        0,
        .66,
        curve: Curves.ease,
      ).transform(anim.value);
      final v = _ease.transform(anim.value);
      final inset = MediaQuery.of(ctx).viewInsets.bottom;
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(ctx).maybePop(),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 4,
                  sigmaY: 4,
                ),
                child: ColoredBox(color: _c(0, 0, 0, .6 * f)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 60 * (1 - v)),
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class ProfileSheetPanel extends StatelessWidget {
  const ProfileSheetPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.small,
    required this.body,
    required this.actions,
  });
  final String icon;
  final String title;
  final String small;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = math.min(
      mq.size.height * .88,
      mq.size.height - mq.viewInsets.bottom - mq.padding.top,
    );
    final side = BorderSide(color: _c(255, 255, 255, .14));
    return Align(
      alignment: Alignment.bottomCenter,
      // 1px down so the (uniform) bottom border sits off-screen, like `border-bottom:0`
      child: Transform.translate(
        offset: const Offset(0, 1),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: maxH),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, 20, 16, 18 + mq.padding.bottom),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.fromBorderSide(side),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                    _c(255, 255, 255, .07),
                    const Color(0xFF0A0A0A),
                  ),
                  Color.alphaBlend(
                    _c(255, 255, 255, .015),
                    const Color(0xFF0A0A0A),
                  ),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      ProfileIconBox(
                        inner: icon,
                        size: 46,
                        radius: 16,
                        iconSize: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: _t(17, 600, Colors.white, h: 1.2),
                            ),
                            Text(small, style: _t(11, 400, _c(156, 163, 199))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: body,
                  ),
                ),
                for (final a in actions)
                  Padding(padding: const EdgeInsets.only(top: 12), child: a),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sheet body building blocks (h4 / bullet list / paragraph / footer note).
class SheetH4 extends StatelessWidget {
  const SheetH4(this.text, {super.key, this.first = false});
  final String text;
  final bool first;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: first ? 2 : 16, bottom: 6),
    child: Text(text, style: _t(13, 600, _c(230, 255, 246))),
  );
}

class SheetList extends StatelessWidget {
  const SheetList(this.items, {super.key});
  final List<String> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 5),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  items[i],
                  style: _t(12, 400, _c(201, 214, 209), h: 1.6),
                ),
              ),
              Positioned(
                left: 3,
                top: 8,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _c(76, 201, 170),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class SheetP extends StatelessWidget {
  const SheetP(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: _t(12, 400, _c(201, 214, 209), h: 1.6));
}

class SheetFoot extends StatelessWidget {
  const SheetFoot(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(text, style: _t(11, 400, _c(156, 163, 199), h: 1.5)),
  );
}
