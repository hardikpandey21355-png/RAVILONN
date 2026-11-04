import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/rs_kit.dart';
import '../data/profile_mock.dart';
import 'profile_group.dart';

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);

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

const String _wallet =
    '<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16" cy="14" r="1"/>';

class UpiSheet extends StatefulWidget {
  const UpiSheet({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onPickScreenshot,
    required this.onSaved,
  });
  final UpiState initial;
  final Future<UpiResult> Function(String upi, XFile? shot) onSave;
  final Future<XFile?> Function() onPickScreenshot;
  final ValueChanged<UpiResult> onSaved;
  @override
  State<UpiSheet> createState() => _UpiSheetState();
}

class _UpiSheetState extends State<UpiSheet> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.initial.upi,
  );
  final FocusNode _focus = FocusNode();
  late bool _hasShot = widget.initial.hasShot;
  XFile? _picked;
  String _msg = '';
  bool _msgOk = false;
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _say(String t, {bool ok = false}) => setState(() {
    _msg = t;
    _msgOk = ok;
  });

  String get _shotLabel => _picked != null
      ? 'Selected: ${_picked!.name}'
      : (_hasShot
            ? 'Screenshot saved ✓ (tap to replace)'
            : 'Tap to add a screenshot');

  Future<void> _pick() async {
    XFile? image;
    try {
      image = await widget.onPickScreenshot();
    } catch (error) {
      if (mounted) _say(error.toString());
      return;
    }
    if (!mounted) return;
    if (image != null) _picked = image;
    _say('');
  }

  Future<void> _save() async {
    if (_busy) return;
    final u = _ctl.text.trim();
    if (!RegExp(r'^[\w.\-]{2,}@[A-Za-z]{2,}$').hasMatch(u)) {
      _say('Enter a valid UPI ID, like name@upi.');
      _focus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _msg = '';
    });
    UpiResult res;
    try {
      res = await widget.onSave(u, _picked);
    } catch (error) {
      res = UpiResult(
        ok: false,
        error: error.toString().isEmpty
            ? 'Network problem. Try again.'
            : error.toString(),
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      _say(res.error ?? 'Could not save. Try again.');
      return;
    }
    _ctl.text = res.upi.isEmpty ? u : res.upi;
    setState(() {
      _hasShot = res.hasShot;
      _picked = null;
    });
    widget.onSaved(res);
    _say('UPI ID saved.', ok: true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final off = MediaQuery.disableAnimationsOf(context);
    final d250 = off ? Duration.zero : const Duration(milliseconds: 250);
    return ProfileSheetPanel(
      icon: _wallet,
      title: 'UPI for withdrawals',
      small: 'Your winnings are sent to this UPI ID',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            label: 'UPI ID',
            child: _UpiInput(controller: _ctl, focus: _focus),
          ),
          _Field(
            label: 'Screenshot of your UPI app (optional)',
            child: _Pressable(
              scale: 1,
              onTap: _pick,
              builder: (down) => TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  end: down ? _c(110, 230, 195, .8) : _c(76, 201, 170, .55),
                ),
                duration: d250,
                builder: (_, bc, _) => CustomPaint(
                  foregroundPainter: _DashedRRect(bc ?? _c(76, 201, 170, .55)),
                  child: AnimatedContainer(
                    duration: d250,
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: down
                          ? _c(76, 201, 170, .14)
                          : _c(76, 201, 170, .07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _shotLabel,
                      textAlign: TextAlign.center,
                      style: _t(12, 400, const Color(0xFF9FE9D0)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(
              'Enter the UPI ID exactly as it appears in your UPI app. A screenshot showing your name and UPI ID helps us pay you faster. Money is sent only to this UPI ID.',
              style: _t(11, 400, const Color(0xFF8D9A95), h: 1.5),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 18),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _msg,
                style: _t(
                  12,
                  400,
                  _msgOk ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        ProfileButton(
          label: 'Save UPI ID',
          kind: ProfileButtonKind.primary,
          onTap: _busy ? null : _save,
        ),
        ProfileButton(
          label: 'Close',
          kind: ProfileButtonKind.ghost,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 5),
          child: Text(label, style: _t(11, 400, const Color(0xFF9AA8A3))),
        ),
        child,
      ],
    ),
  );
}

class _UpiInput extends StatelessWidget {
  const _UpiInput({required this.controller, required this.focus});
  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final off = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: focus,
      builder: (context, _) {
        final f = focus.hasFocus;
        return Stack(
          children: [
            AnimatedContainer(
              duration: off ? Duration.zero : const Duration(milliseconds: 250),
              curve: Curves.ease,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: _c(255, 255, 255, .07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: f ? _c(76, 201, 170, .7) : _c(255, 255, 255, .16),
                ),
                boxShadow: f
                    ? [BoxShadow(color: _c(47, 143, 122, .25), spreadRadius: 3)]
                    : const [],
              ),
              child: TextField(
                controller: controller,
                focusNode: focus,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                cursorColor: Colors.white,
                style: _t(15, 500, Colors.white),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'name@upi',
                  hintStyle: _t(15, 500, _c(180, 192, 187)),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 1,
              height: 1,
              child: IgnorePointer(
                child: ColoredBox(color: _c(255, 255, 255, .08)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashedRRect extends CustomPainter {
  _DashedRRect(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    ).deflate(.75);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in (Path()..addRRect(rr)).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color;
}
