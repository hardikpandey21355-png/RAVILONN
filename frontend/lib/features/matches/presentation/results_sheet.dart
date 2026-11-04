import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/rs_kit.dart';
import '../data/matches_mock.dart';

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
Duration _d(BuildContext c, int ms) => MediaQuery.disableAnimationsOf(c)
    ? Duration.zero
    : Duration(milliseconds: ms);

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

const String _pTrophy =
    r'<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>';
const String _pWallet =
    r'<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16" cy="14" r="1"/>';

String _inr(int n) {
  final s = n.abs().toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    var head = s.substring(0, s.length - 3);
    final tail = s.substring(s.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    out = '${parts.join(',')},$tail';
  }
  return n < 0 ? '-$out' : out;
}

Widget _glowLine(double inset, double alpha) => Positioned(
  top: 0,
  left: inset,
  right: inset,
  height: 1,
  child: IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rsC(255, 255, 255, 0),
            rsC(255, 255, 255, alpha),
            rsC(255, 255, 255, alpha),
            rsC(255, 255, 255, 0),
          ],
          stops: const [0, .12, .88, 1],
        ),
      ),
    ),
  ),
);

/// Bottom sheet with the reward of one match. Slides up 60px + fades (450ms), barrier is black .6 with blur 8.
Future<void> showResultsSheet(BuildContext context, MatchItem item) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Close results',
    barrierColor: Colors.transparent,
    transitionDuration: _d(context, 450),
    pageBuilder: (ctx, anim, _) => _ResultsSheet(item: item, anim: anim),
    transitionBuilder: (ctx, anim, _, child) => child,
  );
}

class _ResultsSheet extends StatelessWidget {
  const _ResultsSheet({required this.item, required this.anim});
  final MatchItem item;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final r = item.result ?? const MatchResult(declared: false);
    final safe = MediaQuery.paddingOf(context).bottom;

    final String value, label, note;
    Color valueColor = Colors.white;
    if (r.declared) {
      value = '₹${_inr(r.won)}';
      label = 'Reward won';
      if (r.won > 0) valueColor = rsC(74, 222, 128);
      note = r.won > 0
          ? 'Congratulations! Your reward was added to your winnings.'
          : 'No reward this time. Better luck in the next match!';
    } else {
      value = 'Pending';
      label = 'Reward';
      note =
          'Results are being verified. Rewards can take up to 24 hours to reach your wallet.';
    }

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: anim,
        builder: (ctx, _) {
          final t = anim.value.clamp(0.0, 1.0);
          final e = kRsEase.transform(t);
          final bt = Curves.ease.transform((t * 450 / 300).clamp(0.0, 1.0));
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 3 * bt + .001,
                      sigmaY: 3 * bt + .001,
                    ),
                    child: ColoredBox(color: rsC(0, 0, 0, .6 * bt)),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: e,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      60 * (1 - e) + 2,
                    ), // +2 hides the panel's bottom border under the screen edge
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(16, 22, 16, 18 + safe + 2),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          color: const Color(0xFF0A0F0E),
                          border: Border.all(color: rsC(255, 255, 255, .14)),
                          boxShadow: [
                            BoxShadow(
                              color: rsC(44, 150, 124, .15),
                              blurRadius: 40,
                              offset: const Offset(0, -10),
                            ),
                          ],
                        ),
                        key: const ValueKey<String>('match-results-sheet'),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: rsC(76, 201, 170, .14),
                                border: Border.all(
                                  color: rsC(110, 230, 195, .4),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: rsC(54, 184, 152, .25),
                                    blurRadius: 22,
                                  ),
                                ],
                              ),
                              child: _icon(_pTrophy, '#6ee6c3', 28),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.mode,
                              textAlign: TextAlign.center,
                              style: _t(17, FontWeight.w600, Colors.white),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'FREE FIRE • ${item.team} | ${item.map}',
                              textAlign: TextAlign.center,
                              style: _t(
                                12,
                                FontWeight.w400,
                                rsC(154, 168, 163),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: const Color(0xFF111916),
                                  border: Border.all(
                                    color: rsC(255, 255, 255, .12),
                                  ),
                                ),
                                child: Stack(
                                  key: const ValueKey<String>(
                                    'match-result-prize-box',
                                  ),
                                  children: [
                                    _glowLine(20, .1),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 14,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            _icon(_pWallet, '#fbbf24', 22),
                                            const SizedBox(height: 4),
                                            Text(
                                              value,
                                              textAlign: TextAlign.center,
                                              style: _t(
                                                24,
                                                FontWeight.w700,
                                                valueColor,
                                              ),
                                            ),
                                            Text(
                                              label,
                                              textAlign: TextAlign.center,
                                              style: _t(
                                                11,
                                                FontWeight.w400,
                                                rsC(154, 168, 163),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              note,
                              textAlign: TextAlign.center,
                              style: _t(
                                11,
                                FontWeight.w400,
                                rsC(154, 168, 163),
                                h: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _CloseButton(
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
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
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return RsPress(
      scale: .93,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
            color: rsC(20, 44, 38, .5),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [rsC(255, 255, 255, .15), rsC(255, 255, 255, .04)],
            ),
            border: Border.all(color: rsC(255, 255, 255, .18)),
            boxShadow: [
              BoxShadow(
                color: rsC(0, 0, 0, .35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              _glowLine(23, .2),
              Center(
                child: Text(
                  'Close',
                  style: _t(13, FontWeight.w600, Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
