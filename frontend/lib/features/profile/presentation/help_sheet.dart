import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/rs_kit.dart';
import 'profile_group.dart';

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
  const _Pressable({required this.child, this.onTap, this.scale = .98});
  final Widget child;
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
        child: widget.child,
      ),
    );
  }
}

const String _users =
    '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6.5 6.5 0 0 1 3.5 6"/>';
const String _mail =
    '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>';
const String _arrow = '<path d="M9 5l7 7-7 7"/>';
const String _gmail =
    'https://mail.google.com/mail/?view=cm&fs=1&to=rivalon.smash%40gmail.com';

class HelpSheet extends StatelessWidget {
  const HelpSheet({super.key, this.userEmail = '', this.onOpenUrl});
  final String userEmail;
  final Future<void> Function(String)? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final email = userEmail.trim();
    return ProfileSheetPanel(
      icon: _users,
      title: 'Help and support',
      small: 'Payment, wallet or match problems',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pressable(
            scale: .985,
            onTap: () {
              final openUrl = onOpenUrl;
              if (openUrl != null) unawaited(openUrl(_gmail));
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ProfileGlass(
                radius: 20,
                padding: const EdgeInsets.all(12),
                base: Colors.transparent,
                colors: [
                  _c(20, 96, 78, .5),
                  _c(6, 26, 22, .9),
                  _c(40, 140, 115, .35),
                ],
                stops: const [0, .55, 1],
                angle: 115,
                border: _c(76, 201, 170, .3),
                sigma: 0,
                hl: 0,
                shadow: const [],
                child: Row(
                  children: [
                    const ProfileIconBox(inner: _mail),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Email us',
                            style: _t(11, 400, _c(156, 163, 199)),
                          ),
                          Text(
                            'rivalon.smash@gmail.com',
                            style: _t(14, 500, Colors.white, h: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _icon(_arrow, '#9ca3c7', 16),
                  ],
                ),
              ),
            ),
          ),
          const SheetH4('When you contact us, please send'),
          SheetList([
            email.isEmpty
                ? 'The email you log in with.'
                : 'The email you log in with ($email).',
            'Your Free Fire name and UID.',
            'The tournament name and time, if it is about a match.',
            'A screenshot, or the transaction details, if it is about a payment or withdrawal.',
          ]),
          const SheetFoot(
            'Also read Rules and fair play for how refunds, results and withdrawals work.',
          ),
        ],
      ),
      actions: [
        ProfileButton(
          label: 'Close',
          kind: ProfileButtonKind.ghost,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
