// Top toast: slide-in from top, 3s progress bar, tap or timeout to hide.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';
import 'profile_group.dart' show ProfileGlass;

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);
const Curve _ease = kRsEase;
Widget _icon(String inner, String hex, double size) => SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" '
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>',
      width: size,
      height: size,
    );

enum ProfileToastType { err, warn, ok }

const Map<ProfileToastType, String> _inner = {
  ProfileToastType.err: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5M12 16h.01"/>',
  ProfileToastType.warn: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17h.01"/>',
  ProfileToastType.ok: '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/>',
};
const Map<ProfileToastType, String> _hex = {
  ProfileToastType.err: '#f87171',
  ProfileToastType.warn: '#fbbf24',
  ProfileToastType.ok: '#4ade80',
};
Color _col(ProfileToastType t, [double o = 1]) {
  switch (t) {
    case ProfileToastType.err:
      return _c(248, 113, 113, o);
    case ProfileToastType.warn:
      return _c(251, 191, 36, o);
    case ProfileToastType.ok:
      return _c(74, 222, 128, o);
  }
}

class ProfileToast {
  ProfileToast._();
  static _ToastViewState? _active;
  static Timer? _wait;

  /// A new toast hides the old one first, then shows after 220ms.
  static void show(BuildContext context, String title, ProfileToastType type, [String? text]) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _wait?.cancel();
    void mount() {
      if (!overlay.mounted) return;
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _ToastView(title: title, type: type, text: text, onGone: () => entry.remove()),
      );
      overlay.insert(entry);
    }

    final live = _active;
    if (live != null) {
      live.dismiss();
      _wait = Timer(const Duration(milliseconds: 220), mount);
    } else {
      mount();
    }
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.title, required this.type, required this.text, required this.onGone});
  final String title;
  final ProfileToastType type;
  final String? text;
  final VoidCallback onGone;
  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final AnimationController _bar = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  Timer? _timer;
  bool _gone = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    ProfileToast._active = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.duration = Duration.zero;
      _in.reverseDuration = Duration.zero;
      _in.value = 1;
    } else {
      _in.forward();
      _bar.forward();
    }
    _timer = Timer(const Duration(seconds: 3), dismiss);
  }

  void dismiss() {
    if (_gone) return;
    _gone = true;
    _timer?.cancel();
    if (ProfileToast._active == this) ProfileToast._active = null;
    _in.reverse().whenComplete(widget.onGone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (ProfileToast._active == this) ProfileToast._active = null;
    _in.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final off = MediaQuery.disableAnimationsOf(context);
    final top = 14 + MediaQuery.paddingOf(context).top;
    final hasText = widget.text != null && widget.text!.isNotEmpty;
    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedBuilder(
            animation: _in,
            builder: (_, child) {
              final v = _ease.transform(_in.value);
              final f = const Interval(0, .7, curve: _ease).transform(_in.value);
              return Opacity(
                opacity: f,
                child: Transform.translate(
                  offset: Offset(0, -24 * (1 - v)),
                  child: Transform.scale(scale: .95 + .05 * v, alignment: Alignment.topCenter, child: child),
                ),
              );
            },
            child: Material(
              type: MaterialType.transparency,
              child: GestureDetector(
                onTap: dismiss,
                child: ProfileGlass(
                  radius: 22,
                  base: _c(8, 16, 14, .84),
                  colors: [_c(255, 255, 255, .12), _c(255, 255, 255, .03)],
                  stops: const [0, 1],
                  angle: 180,
                  border: _col(type, .4),
                  sigma: 22,
                  hl: .18,
                  shadow: [BoxShadow(color: _c(0, 0, 0, .55), blurRadius: 36, offset: const Offset(0, 14))],
                  child: Stack(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _c(255, 255, 255, .07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _col(type)),
                          ),
                          child: _icon(_inner[type]!, _hex[type]!, 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(widget.title, style: _t(13, 600, Colors.white, h: 1.3)),
                            if (hasText)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(widget.text!, style: _t(11.5, 400, _c(196, 211, 206), h: 1.45)),
                              ),
                          ]),
                        ),
                      ]),
                    ),
                    if (!off)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 3,
                        child: AnimatedBuilder(
                          animation: _bar,
                          builder: (_, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (1 - _bar.value).clamp(0.0, 1.0),
                            child: ColoredBox(color: _col(type)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}