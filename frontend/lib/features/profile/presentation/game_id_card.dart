import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';
import '../data/profile_mock.dart';
import 'profile_group.dart';
import 'profile_toast.dart';

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(double size, int w, Color color, {double? ls, double? h}) =>
    rsT(size, w: FontWeight.values[w ~/ 100 - 1], color: color, ls: ls, h: h);
Widget _icon(String inner, String hex, double size) => SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" '
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">$inner</svg>',
      width: size,
      height: size,
    );

const String _flame = '<path d="M12 3c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z"/>';
const String _user = '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>';

class GameIdCard extends StatefulWidget {
  const GameIdCard({
    super.key,
    required this.initial,
    required this.onSave,
    this.onSaved,
  });
  final GameIdState initial;
  final Future<GameIdResult> Function(String ign, String uid) onSave;
  final ValueChanged<GameIdResult>? onSaved;
  @override
  State<GameIdCard> createState() => _GameIdCardState();
}

class _GameIdCardState extends State<GameIdCard> {
  late final TextEditingController _ign = TextEditingController(text: widget.initial.ign);
  late final TextEditingController _uid = TextEditingController(text: widget.initial.uid);
  final FocusNode _ignF = FocusNode();
  final FocusNode _uidF = FocusNode();
  late bool _saved = widget.initial.saved;
  late bool _editing = !widget.initial.saved;
  bool _busy = false;

  @override
  void dispose() {
    _ign.dispose();
    _uid.dispose();
    _ignF.dispose();
    _uidF.dispose();
    super.dispose();
  }

  void _focusLater(FocusNode f) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? f.requestFocus() : null);

  Future<void> _tap() async {
    if (_busy) return;
    if (!_editing) {
      setState(() => _editing = true);
      _focusLater(_ignF);
      return;
    }
    final n = _ign.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final u = _uid.text.trim();
    if (n.length < 2) {
      ProfileToast.show(context, 'Enter your in-game name', ProfileToastType.warn,
          'Type your Free Fire name exactly as it appears in the game.');
      _ignF.requestFocus();
      return;
    }
    if (u.length < 8) {
      ProfileToast.show(context, 'Enter a valid UID', ProfileToastType.warn, 'Your Free Fire UID has 8 to 12 digits.');
      _uidF.requestFocus();
      return;
    }
    setState(() => _busy = true);
    GameIdResult res;
    try {
      res = await widget.onSave(n, u);
    } catch (e) {
      res = const GameIdResult(ok: false, error: 'Network problem. Try again.');
    }
    if (!mounted) return;
    if (!res.ok) {
      setState(() => _busy = false);
      ProfileToast.show(context, 'Could not save Game ID', ProfileToastType.err, res.error ?? 'Something went wrong. Try again.');
      return;
    }
    _ign.text = res.ign.isEmpty ? n : res.ign;
    _uid.text = res.uid.isEmpty ? u : res.uid;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = false;
      _saved = true;
      _editing = false;
    });
    widget.onSaved?.call(
      GameIdResult(ok: true, ign: _ign.text, uid: _uid.text),
    );
    ProfileToast.show(context, 'Game ID saved', ProfileToastType.ok, 'You can join matches now.');
  }

  @override
  Widget build(BuildContext context) {
    final shadow = Shadow(color: _c(0, 0, 0, .9), blurRadius: 10, offset: const Offset(0, 1));
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D0C),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _c(255, 255, 255, .16)),
        boxShadow: [BoxShadow(color: _c(0, 0, 0, .28), blurRadius: 32, offset: const Offset(0, 12))],
      ),
      child: Stack(children: [
        // background picture, faded in vertically (transparent @10% -> opaque @70%)
        Positioned.fill(
          child: IgnorePointer(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black],
                stops: [.1, .7],
              ).createShader(r),
              child: Opacity(
                opacity: .5,
                child: Image.asset(
                  'assets/images/gid_bg.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, _) {
                    debugPrint('gid_bg.jpg could not be loaded: $e');
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0B0B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _c(255, 255, 255, .22)),
                  ),
                  child: _icon(_flame, '#fb923c', 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Free Fire',
                        style: _t(14, 700, Colors.white, h: 1.2).copyWith(
                            shadows: [Shadow(color: _c(0, 0, 0, .8), blurRadius: 12, offset: const Offset(0, 1))])),
                    Text('Needed to join any match', style: _t(11, 400, const Color(0xFFDFE8E4)).copyWith(shadows: [shadow])),
                  ]),
                ),
                const SizedBox(width: 10),
                ProfileStatusChip(label: _saved ? 'Ready to play' : 'Required to join', ok: _saved),
              ]),
            ),
            _Field(
              label: 'In-game name',
              child: _GidInput(
                controller: _ign,
                focus: _ignF,
                hint: 'Your Free Fire name',
                readOnly: !_editing,
                formatters: [LengthLimitingTextInputFormatter(20)],
              ),
            ),
            _Field(
              label: 'Free Fire UID',
              child: _GidInput(
                controller: _uid,
                focus: _uidF,
                hint: '8 to 12 digit UID',
                readOnly: !_editing,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
              ),
            ),
            ProfileButton(
              label: _editing ? 'Save Game ID' : 'Edit Game ID',
              kind: _editing ? ProfileButtonKind.gameSave : ProfileButtonKind.gameEdit,
              height: 52,
              iconInner: _editing ? null : _user,
              onTap: _busy ? null : _tap,
            ),
          ]),
        ),
        Positioned(left: 16, right: 16, top: 0, height: 1, child: ColoredBox(color: _c(255, 255, 255, .2))),
      ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Text(label,
                style: _t(11, 400, const Color(0xFFC9CCD1))
                    .copyWith(shadows: [Shadow(color: _c(0, 0, 0, .9), blurRadius: 8, offset: const Offset(0, 1))])),
          ),
          child,
        ]),
      );
}

class _GidInput extends StatelessWidget {
  const _GidInput({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.readOnly,
    required this.formatters,
    this.keyboard,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final bool readOnly;
  final List<TextInputFormatter> formatters;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    final off = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: focus,
      builder: (context, _) {
        final ring = !readOnly && focus.hasFocus;
        return AnimatedContainer(
          duration: off ? Duration.zero : const Duration(milliseconds: 300),
          curve: Curves.ease,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0xFF0C0D0E),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ring ? _c(255, 255, 255, .7) : (readOnly ? _c(255, 255, 255, .16) : _c(255, 255, 255, .22))),
            boxShadow: ring ? [BoxShadow(color: _c(255, 255, 255, .12), spreadRadius: 3)] : const [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focus,
            readOnly: readOnly,
            enableInteractiveSelection: !readOnly,
            keyboardType: keyboard,
            inputFormatters: formatters,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: Colors.white,
            style: _t(15, 500, readOnly ? const Color(0xFFD5DAD8) : Colors.white),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: _t(15, 500, _c(180, 192, 187)),
            ),
          ),
        );
      },
    );
  }
}