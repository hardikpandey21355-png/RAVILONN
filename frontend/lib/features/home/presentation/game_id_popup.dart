import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/rs_kit.dart';
import '../../profile/data/profile_mock.dart';

/// in-memory "already asked in this session" flag
class RsSession {
  static bool gidAsked = false;
}

Future<void> showGameIdPopup(
  BuildContext context, {
  Future<GameIdResult> Function(String ign, String uid)? onSave,
}) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: 'Set up your Game ID',
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (ctx, anim, _) => _GameIdDialog(anim: anim, onSave: onSave),
    transitionBuilder: (ctx, anim, sec, child) => child,
  );
}

class _GameIdDialog extends StatefulWidget {
  const _GameIdDialog({required this.anim, this.onSave});
  final Animation<double> anim;
  final Future<GameIdResult> Function(String ign, String uid)? onSave;
  @override
  State<_GameIdDialog> createState() => _GameIdDialogState();
}

class _GameIdDialogState extends State<_GameIdDialog> {
  final _ign = TextEditingController();
  final _uid = TextEditingController();
  final _ignNode = FocusNode();
  final _uidNode = FocusNode();
  String _err = '';
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted && !_done) _ignNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ign.dispose();
    _uid.dispose();
    _ignNode.dispose();
    _uidNode.dispose();
    super.dispose();
  }

  void _close() {
    if (_busy) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  Future<void> _save() async {
    final n = _ign.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final u = _uid.text.trim();
    if (n.length < 2) {
      setState(() => _err = 'Enter your in-game name.');
      _ignNode.requestFocus();
      return;
    }
    if (!RegExp(r'^\d{8,12}$').hasMatch(u)) {
      setState(() => _err = 'Enter a valid UID (8 to 12 digits).');
      _uidNode.requestFocus();
      return;
    }
    setState(() {
      _err = '';
      _busy = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    GameIdResult result;
    try {
      if (widget.onSave != null) {
        result = await widget.onSave!(n, u);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        result = GameIdResult(ok: true, ign: n, uid: u);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = error.toString().isEmpty
            ? 'Network problem. Try again.'
            : error.toString();
      });
      return;
    }
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _err = result.error ?? 'Could not save Game ID. Try again.';
      });
      return;
    }
    AuthSession.ign.value = result.ign;
    AuthSession.gameUid.value = result.uid;
    AuthSession.gameOk.value = true;
    setState(() {
      _busy = false;
      _done = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: widget.anim,
        builder: (context, _) {
          final a = Curves.ease.transform(widget.anim.value.clamp(0.0, 1.0));
          final c = kRsEase.transform(widget.anim.value.clamp(0.0, 1.0));
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: _close,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 12 * a + .001,
                    sigmaY: 12 * a + .001,
                  ),
                  child: ColoredBox(color: rsK(.45 * a)),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + inset),
                child: Center(
                  child: SingleChildScrollView(
                    child: Opacity(
                      opacity: a,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - c)),
                        child: Transform.scale(
                          scale: .96 + .04 * c,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: SizedBox(
                              width: double.infinity,
                              child: _card(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _logo({required Widget icon, Gradient? gradient}) => Container(
    width: 56,
    height: 56,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: rsC(165, 255, 228, .5)),
      gradient:
          gradient ??
          const RadialGradient(
            center: Alignment(-.44, -1),
            radius: 1.4,
            colors: [Color(0xFF5DF0C5), Color(0xFF22B08A), Color(0xFF0B6B52)],
            stops: [0, .42, 1],
          ),
    ),
    alignment: Alignment.center,
    child: icon,
  );

  Widget _card() {
    return RsGlass(
      radius: 28,
      blur: 26,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [rsW(.2), rsW(.07)],
      ),
      border: rsW(.3),
      topLight: .4,
      shadows: [
        BoxShadow(color: rsK(.55), blurRadius: 60, offset: const Offset(0, 24)),
      ],
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 14),
      child: _done ? _doneView() : _form(),
    );
  }

  Widget _doneView() => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _logo(
            icon: const RsIcon('check', size: 28, color: Colors.white),
            gradient: const LinearGradient(
              colors: [Color(0xFF15803D), Color(0xFF22C55E)],
            ),
          ),
          Text(
            'Game ID saved',
            textAlign: TextAlign.center,
            style: rsT(18, w: FontWeight.w700, h: 1.25),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Text(
              'You can join tournaments now.',
              textAlign: TextAlign.center,
              style: rsT(12, color: const Color(0xFFD1D5F0), h: 1.5),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _logo(
            icon: const RsIcon('flame', size: 28, color: Colors.white),
          ),
        ),
        Text(
          'Set up your Game ID',
          textAlign: TextAlign.center,
          style: rsT(18, w: FontWeight.w700, h: 1.25),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
          child: Text(
            'Add your Free Fire name and UID to join tournaments. Enter them exactly as they appear in the game.',
            textAlign: TextAlign.center,
            style: rsT(12, color: const Color(0xFFD1D5F0), h: 1.5),
          ),
        ),
        _GpField(
          label: 'In-game name',
          hint: 'Your Free Fire name',
          controller: _ign,
          node: _ignNode,
          formatters: [LengthLimitingTextInputFormatter(20)],
        ),
        const SizedBox(height: 10),
        _GpField(
          label: 'Free Fire UID',
          hint: '8 to 12 digit UID',
          controller: _uid,
          node: _uidNode,
          keyboard: TextInputType.number,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
        ),
        Container(
          constraints: const BoxConstraints(minHeight: 18),
          margin: const EdgeInsets.fromLTRB(2, 12, 2, 6),
          child: Text(
            _err,
            style: rsT(12, color: const Color(0xFFFCA5A5), h: 1.4),
          ),
        ),
        Opacity(
          opacity: _busy ? .55 : 1,
          child: RsPress(
            onTap: _busy ? null : _save,
            child: RsGlass(
              radius: 999,
              base: rsC(12, 22, 20, .45),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [rsC(110, 230, 195, .26), rsC(27, 111, 92, .2)],
              ),
              border: rsC(140, 240, 210, .38),
              topLight: _busy ? 0 : .26,
              shadows: _busy
                  ? const []
                  : [
                      BoxShadow(
                        color: rsK(.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    'Save Game ID',
                    style: rsT(
                      14,
                      w: FontWeight.w600,
                      color: const Color(0xFFEAFFF7),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        RsPress(
          onTap: _close,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Center(
              child: Text(
                'Maybe later',
                style: rsT(12, color: const Color(0xFFD1D5F0)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GpField extends StatefulWidget {
  const _GpField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.node,
    this.keyboard,
    this.formatters,
  });
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode node;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  @override
  State<_GpField> createState() => _GpFieldState();
}

class _GpFieldState extends State<_GpField> {
  @override
  void initState() {
    super.initState();
    widget.node.addListener(_r);
  }

  @override
  void dispose() {
    widget.node.removeListener(_r);
    super.dispose();
  }

  void _r() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final f = widget.node.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(
            widget.label,
            style: rsT(11, color: const Color(0xFFD1D5F0)),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: rsW(.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: f ? rsC(76, 201, 170, .7) : rsW(.26)),
            boxShadow: f
                ? [BoxShadow(color: rsC(47, 143, 122, .25), spreadRadius: 3)]
                : const [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.node,
            keyboardType: widget.keyboard,
            inputFormatters: widget.formatters,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: kRsG2,
            style: rsT(16, w: FontWeight.w500),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: rsT(
                16,
                w: FontWeight.w500,
                color: const Color(0xFFB4BAD8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
