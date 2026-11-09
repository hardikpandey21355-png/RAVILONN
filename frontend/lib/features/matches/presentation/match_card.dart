import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/rs_kit.dart';
import '../data/matches_mock.dart';
import 'results_sheet.dart';

// ------------------------------------------------------------------ helpers
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
const String _pTicket =
    r'<path d="M3 9a2 2 0 0 0 0 6v3h18v-3a2 2 0 0 1 0-6V6H3z"/><path d="M13 6v12" stroke-dasharray="2 2"/>';
const String _pUsers =
    r'<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14a6.5 6.5 0 0 1 3.5 6"/>';
const String _pArrow = r'<path d="M9 5l7 7-7 7"/>';
const String _pClock =
    r'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
const String _pSwords =
    r'<path d="M4 4l9 9M20 4l-9 9M3 21l4-4M21 21l-4-4M8 16l-3 3M16 16l3 3"/>';
const String _pFlame =
    r'<path d="M12 3c1 4 5 5 5 10a5 5 0 0 1-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z"/>';
const String _pCheck = r'<path d="M5 12l5 5 9-10"/>';
const String _pLock =
    r'<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>';
const String _pCopy =
    r'<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/>';

/// 1250 -> 1,250 and 125000 -> 1,25,000 (Indian grouping, like toLocaleString('en-IN')).
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

/// Same as the website's rsClock: days show only when the countdown is 24 hours or more.
String _clock(int secs) {
  final s = secs < 0 ? 0 : secs;
  final d = s ~/ 86400,
      h = (s % 86400) ~/ 3600,
      m = (s % 3600) ~/ 60,
      x = s % 60;
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d > 0 ? '${d}d ' : ''}${p(h)}:${p(m)}:${p(x)}';
}

/// Decoration + the thin light line along the top edge (the website's "inset 0 1px 0" highlight).
class _Surface extends StatelessWidget {
  const _Surface({
    this.decoration,
    this.padding = EdgeInsets.zero,
    this.glow = 0,
    this.radius = 0,
    required this.child,
  });
  final BoxDecoration? decoration;
  final EdgeInsets padding;
  final double glow, radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      fit: StackFit.passthrough,
      children: [
        Padding(padding: padding, child: child),
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

// ------------------------------------------------------------------ buttons
enum _BtnKind { ghost, primary, danger }

/// The radial glow of the green button is a wide ellipse on the website; this stretches the circle sideways.
class _XStretch extends GradientTransform {
  const _XStretch(this.k, this.cxFraction);
  final double k, cxFraction;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.left + bounds.width * cxFraction;
    return Matrix4.translationValues(cx, 0, 0) *
        Matrix4.diagonal3Values(k, 1, 1) *
        Matrix4.translationValues(-cx, 0, 0);
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.kind, {this.icon, this.onTap});
  final String label;
  final _BtnKind kind;
  final String? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    late final BoxDecoration deco;
    late final Color textColor;
    late final String iconHex;
    double glow;
    List<Shadow>? textShadow;
    var shade = false;
    switch (kind) {
      case _BtnKind.ghost:
        deco = BoxDecoration(
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
        );
        textColor = Colors.white;
        iconHex = '#ffffff';
        glow = .2;
        break;
      case _BtnKind.primary:
        deco = BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          gradient: const RadialGradient(
            center: Alignment(-.44, -1),
            radius: 1.7,
            colors: [Color(0xFF5DF0C5), Color(0xFF22B08A), Color(0xFF0B6B52)],
            stops: [0, .42, 1],
            transform: _XStretch(5, .28),
          ),
          border: Border.all(color: rsC(165, 255, 228, .5)),
          boxShadow: [BoxShadow(color: rsC(54, 184, 152, .25), blurRadius: 18)],
        );
        textColor = Colors.white;
        iconHex = '#ffffff';
        glow = .5;
        textShadow = [
          Shadow(
            color: rsC(0, 50, 36, .5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ];
        shade = true;
        break;
      case _BtnKind.danger:
        deco = BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          color: rsC(239, 68, 68, .08),
          border: Border.all(color: rsC(239, 68, 68, .45)),
        );
        textColor = const Color(0xFFFCA5A5);
        iconHex = '#fca5a5';
        glow = .06;
        break;
    }

    final row = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: _t(
              13,
              FontWeight.w600,
              textColor,
            ).copyWith(shadows: textShadow),
          ),
          if (icon != null) ...[
            const SizedBox(width: 6),
            _icon(icon!, iconHex, 15),
          ],
        ],
      ),
    );

    return RsPress(
      scale: .93,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: _Surface(
          radius: 23,
          glow: glow,
          decoration: deco,
          child: shade
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 20,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [rsC(0, 60, 45, 0), rsC(0, 60, 45, .4)],
                            ),
                          ),
                        ),
                      ),
                      row,
                    ],
                  ),
                )
              : row,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ leave confirm
/// Replaces the browser confirm(): "Leave this match? Your entry fee will be refunded to your wallet."
Future<bool?> showLeaveConfirm(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel',
    barrierColor: rsC(0, 0, 0, .6),
    transitionDuration: _d(context, 300),
    pageBuilder: (ctx, _, _) => const _LeaveDialog(),
    transitionBuilder: (ctx, a, _, child) => AnimatedBuilder(
      animation: a,
      child: child,
      builder: (_, c) {
        final e = kRsEase.transform(a.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: e,
          child: Transform.scale(scale: .96 + .04 * e, child: c),
        );
      },
    ),
  );
}

class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog();
  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF0A0F0E),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [rsC(255, 255, 255, .08), rsC(255, 255, 255, .015)],
                ),
                border: Border.all(color: rsC(255, 255, 255, .14)),
                boxShadow: [
                  BoxShadow(
                    color: rsC(44, 150, 124, .15),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Leave this match?',
                    textAlign: TextAlign.center,
                    style: _t(17, FontWeight.w600, Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your entry fee will be refunded to your wallet.',
                    textAlign: TextAlign.center,
                    style: _t(12, FontWeight.w400, rsC(154, 168, 163), h: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Btn(
                          'Cancel',
                          _BtnKind.ghost,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Btn(
                          'Leave',
                          _BtnKind.danger,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ card
/// One match with the website's time logic: start/end are fixed, the state comes from "now".
class MatchView {
  MatchView(this.item, this.start, this.end, DateTime now)
    : started = !now.isBefore(start),
      completed = !now.isBefore(end);

  final MatchItem item;
  final DateTime start, end;
  final bool started, completed;

  /// Seconds to the start (not started) or to the end (started). 0 when completed.
  int secsAt(DateTime now) {
    if (completed) return 0;
    final target = started ? end : start;
    final s = (target.difference(now).inMilliseconds / 1000).ceil();
    return s < 0 ? 0 : s;
  }
}

class MatchCard extends StatefulWidget {
  const MatchCard({
    super.key,
    required this.view,
    required this.now,
    required this.imageBase,
    required this.onCopy,
    required this.onLeave,
  });

  final MatchView view;
  final ValueListenable<DateTime> now;
  final String imageBase;
  final Future<void> Function(String) onCopy;
  final void Function(String id) onLeave;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  bool _down = false;

  MatchView get v => widget.view;
  MatchItem get m => widget.view.item;
  bool get _loot => m.isLoot;

  @override
  Widget build(BuildContext context) {
    final dur = _d(context, 250);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () {
        if (_down) setState(() => _down = false);
      },
      child: AnimatedScale(
        scale: _down ? .99 : 1,
        duration: dur,
        curve: kRsEase,
        child: AnimatedContainer(
          key: ValueKey<String>('match-card-${m.id}'),
          duration: dur,
          curve: kRsEase,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: _loot ? const Color(0xFF171407) : rsC(12, 16, 15, .5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _loot
                  ? [
                      rsC(247, 215, 116, .14),
                      rsC(25, 21, 8, .96),
                      rsC(247, 215, 116, .06),
                    ]
                  : [
                      rsC(255, 255, 255, .13),
                      rsC(255, 255, 255, .035),
                      rsC(255, 255, 255, .07),
                    ],
              stops: const [0, .45, 1],
            ),
            border: Border.all(
              color: _loot
                  ? rsC(247, 215, 116, _down ? .55 : .32)
                  : _down
                  ? rsC(110, 230, 195, .35)
                  : rsC(255, 255, 255, .14),
            ),
            boxShadow: [
              BoxShadow(
                color: _loot ? rsC(130, 91, 14, .16) : rsC(0, 0, 0, .4),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_imageArea(), _body()],
                ),
                Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  height: 1,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            rsC(255, 255, 255, 0),
                            _loot
                                ? rsC(247, 215, 116, .35)
                                : rsC(255, 255, 255, .18),
                            _loot
                                ? rsC(247, 215, 116, .35)
                                : rsC(255, 255, 255, .18),
                            rsC(255, 255, 255, 0),
                          ],
                          stops: const [0, .12, .88, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- image area
  Widget _image() {
    final path = '${widget.imageBase}${m.img}';
    Widget err(BuildContext c, Object e, StackTrace? s) {
      debugPrint('MatchCard: image could not load: $path ($e)');
      return const SizedBox.shrink(); // the teal gradient below stays visible
    }

    return widget.imageBase.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover, errorBuilder: err)
        : Image.asset(path, fit: BoxFit.cover, errorBuilder: err);
  }

  Widget _imageArea() {
    return SizedBox(
      height: 120,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0C2A24), Color(0xFF101414)],
              ),
            ),
          ),
          Positioned.fill(child: _image()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [rsC(10, 16, 15, .96), rsC(10, 16, 15, 0)],
                  stops: const [0, .78],
                ),
              ),
            ),
          ),
          Positioned(top: 8, left: 8, child: _statusTag()),
          Positioned(
            top: 8,
            right: 8,
            child: v.completed ? _resultPill() : _timeBox(),
          ),
          Positioned(left: 12, right: 12, bottom: 10, child: _titleRow()),
        ],
      ),
    );
  }

  Widget _statusTag() {
    final done = v.completed;
    final txt = done ? 'COMPLETED' : (v.started ? 'LIVE' : 'UPCOMING');
    final fg = done
        ? const Color(0xFF052E16)
        : _loot
        ? const Color(0xFF3B2402)
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: done
            ? rsC(34, 197, 94, .9)
            : _loot
            ? const Color(0xFFF7D774)
            : const Color(0xFF7C3AED), // live and upcoming are both violet
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            _icon(_pCheck, '#052e16', 11, stroke: 3),
            const SizedBox(width: 5),
          ],
          Text(txt, style: _t(9, FontWeight.w600, fg)),
        ],
      ),
    );
  }

  Widget _timeBox() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: rsC(0, 0, 0, .35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: _Surface(
            radius: 14,
            glow: .25,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: rsC(8, 18, 16, .6),
              border: Border.all(
                color: _loot ? rsC(247, 215, 116, .4) : rsC(255, 255, 255, .18),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  v.started ? 'Ends in' : 'Starts in',
                  style: _t(
                    9,
                    FontWeight.w400,
                    _loot ? const Color(0xFFE9D99F) : const Color(0xFFB9CBC5),
                  ),
                ),
                ValueListenableBuilder<DateTime>(
                  valueListenable: widget.now,
                  builder: (_, n, _) => Text(
                    _clock(v.secsAt(n)),
                    style:
                        _t(
                          13,
                          FontWeight.w700,
                          _loot
                              ? const Color(0xFFF7D774)
                              : const Color(0xFFD8FFF1),
                          ls: .5,
                        ).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultPill() {
    final declared = m.result?.declared ?? false;
    final fg = declared ? '#6ee6c3' : '#fbbf24';
    final fgColor = declared
        ? const Color(0xFF6EE6C3)
        : const Color(0xFFFBBF24);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: declared ? rsC(76, 201, 170, .16) : rsC(251, 191, 36, .12),
            border: Border.all(
              color: declared ? rsC(110, 230, 195, .5) : rsC(251, 191, 36, .5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(declared ? _pTrophy : _pClock, fg, 12),
              const SizedBox(width: 5),
              Text(
                declared ? 'Results Declared' : 'Results Pending',
                style: _t(10, FontWeight.w600, fgColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _loot ? rsC(63, 45, 9, .8) : rsC(8, 14, 13, .7),
                border: Border.all(
                  color: _loot
                      ? rsC(247, 215, 116, .45)
                      : rsC(255, 255, 255, .26),
                ),
              ),
              child: _icon(_pFlame, _loot ? '#f7d774' : '#fb923c', 19),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.mode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(15, FontWeight.w700, Colors.white, h: 1.2),
              ),
              Text(
                'FREE FIRE • ${m.team} | ${m.map}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _t(11, FontWeight.w400, const Color(0xFFC4D3CE)),
              ),
              if (m.mySlot != null)
                Text(
                  'YOUR SLOT #${m.mySlot}',
                  style: _t(10, FontWeight.w600, const Color(0xFF6EE6C3)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- body
  Widget _body() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stats(),
          const SizedBox(height: 12),
          if (v.completed)
            _Btn(
              'View Results',
              _BtnKind.ghost,
              icon: _pArrow,
              onTap: () => showResultsSheet(context, m),
            )
          else ...[
            _room(),
            const SizedBox(height: 12),
            if (v.started)
              _Btn(
                'Open Free Fire',
                _BtnKind.primary,
                icon: _pArrow,
                onTap: () {},
              )
            else if (m.room != null)
              Center(
                child: Text(
                  'Room is ready. Leaving this match is closed now.',
                  textAlign: TextAlign.center,
                  style: _t(11, FontWeight.w400, rsC(154, 168, 163)),
                ),
              )
            else if (m.remote)
              Center(
                child: Text(
                  'You are registered for this match.',
                  textAlign: TextAlign.center,
                  style: _t(11, FontWeight.w400, rsC(154, 168, 163)),
                ),
              )
            else
              _Btn(
                'Leave Match',
                _BtnKind.danger,
                onTap: () => widget.onLeave(m.id),
              ),
          ],
        ],
      ),
    );
  }

  Widget _stats() {
    final items = <Widget>[
      _Kv(
        path: _pTrophy,
        hex: _loot ? '#f7d774' : '#fbbf24',
        value: '₹${_inr(m.prize)}',
        label: 'Prize Pool',
        loot: _loot,
      ),
      _Kv(
        path: _pTicket,
        hex: _loot ? '#f7d774' : '#3b82f6',
        value: '₹${_inr(m.fee)}',
        label: 'Entry Paid',
        loot: _loot,
      ),
      _Kv(
        path: _pUsers,
        hex: _loot ? '#f7d774' : '#22d3ee',
        value: '${m.joined} / ${m.slots}',
        label: 'Players',
        loot: _loot,
      ),
      if (m.perKill > 0)
        _Kv(
          path: _pSwords,
          hex: _loot ? '#f7d774' : '#ffffff',
          value: '₹${_inr(m.perKill)}',
          label: 'Per Kill',
          loot: _loot,
        ),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[i]),
            const SizedBox(width: 8),
            Expanded(
              child: i + 1 < items.length
                  ? items[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _room() {
    final open = m.room != null;
    return AnimatedContainer(
      duration: _d(context, 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: open
            ? _loot
                  ? rsC(247, 215, 116, .1)
                  : rsC(76, 201, 170, .09)
            : rsC(255, 255, 255, .05),
        border: Border.all(
          color: open
              ? _loot
                    ? rsC(247, 215, 116, .5)
                    : rsC(110, 230, 195, .5)
              : rsC(255, 255, 255, .14),
        ),
      ),
      child: _Surface(
        radius: 18,
        glow: .08,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: AnimatedSize(
          duration: _d(context, 300),
          curve: kRsEase,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: _d(context, 300),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: open ? _openView(m.room!) : _lockedView(),
          ),
        ),
      ),
    );
  }

  Widget _lockedView() => Row(
    key: const ValueKey('locked'),
    children: [
      _icon(_pLock, '#6ee6c3', 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Room ID and password will appear here as soon as the admin shares them',
          style: _t(12, FontWeight.w400, const Color(0xFFC4D3CE), h: 1.35),
        ),
      ),
    ],
  );

  Widget _openView(MatchRoom r) => Row(
    key: const ValueKey('open'),
    children: [
      Expanded(
        child: _Rv(label: 'Room ID', value: r.roomId, onCopy: widget.onCopy),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _Rv(label: 'Password', value: r.roomPass, onCopy: widget.onCopy),
      ),
    ],
  );
}

class _Kv extends StatelessWidget {
  const _Kv({
    required this.path,
    required this.hex,
    required this.value,
    required this.label,
    this.loot = false,
  });
  final String path, hex, value, label;
  final bool loot;
  @override
  Widget build(BuildContext context) {
    return _Surface(
      radius: 16,
      glow: .08,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: loot ? rsC(247, 215, 116, .07) : rsC(255, 255, 255, .05),
        border: Border.all(
          color: loot ? rsC(247, 215, 116, .22) : rsC(255, 255, 255, .1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(path, hex, 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: _t(14, FontWeight.w600, Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(label, style: _t(10, FontWeight.w400, rsC(154, 168, 163))),
        ],
      ),
    );
  }
}

class _Rv extends StatelessWidget {
  const _Rv({required this.label, required this.value, required this.onCopy});
  final String label, value;
  final Future<void> Function(String) onCopy;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: _t(9, FontWeight.w400, rsC(154, 168, 163))),
              Text(value, style: _t(15, FontWeight.w700, Colors.white, ls: .5)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _CopyBtn(text: value, onCopy: onCopy),
      ],
    );
  }
}

/// Copy icon turns into a green check for 1.2 seconds after copying.
class _CopyBtn extends StatefulWidget {
  const _CopyBtn({required this.text, required this.onCopy});
  final String text;
  final Future<void> Function(String) onCopy;
  @override
  State<_CopyBtn> createState() => _CopyBtnState();
}

class _CopyBtnState extends State<_CopyBtn> {
  bool _done = false;
  Timer? _t;

  Future<void> _tap() async {
    try {
      await widget.onCopy(widget.text);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _done = true);
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _done = false);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RsPress(
      scale: .88,
      onTap: _tap,
      child: AnimatedContainer(
        duration: _d(context, 300),
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: rsC(255, 255, 255, .08),
          border: Border.all(
            color: _done ? const Color(0xFF4ADE80) : rsC(255, 255, 255, .2),
          ),
        ),
        child: _icon(
          _done ? _pCheck : _pCopy,
          _done ? '#4ade80' : '#ffffff',
          16,
        ),
      ),
    );
  }
}
