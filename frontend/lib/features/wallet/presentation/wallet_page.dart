// lib/features/wallet/presentation/wallet_page.dart
//
// Wallet page (UI only) — Flutter clone of wallet.html.
//
// The panels live in their own files as parts of this library, sharing the
// wallet-specific visual helpers while using the shared core kit where suitable.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/api_client.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/rs_kit.dart';
import '../../../core/widgets/wallet_chip.dart';
import '../data/wallet_mock.dart';
import '../data/wallet_repository.dart';

part 'add_money_panel.dart';
part 'balance_card.dart';
part 'move_to_deposit_box.dart';
part 'tick_overlay.dart';
part 'transactions_panel.dart';
part 'wallet_switch.dart';
part 'wallet_toast.dart';
part 'withdraw_panel.dart';

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

TextStyle _t(
  double size,
  FontWeight weight,
  Color color, {
  double? ls,
  double? h,
}) {
  return GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: ls,
    height: h,
  );
}

String inr(int amount) {
  final digits = amount.abs().toString();
  if (digits.length <= 3) return amount < 0 ? '-$digits' : digits;
  final leading = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  var remaining = leading;
  while (remaining.length > 2) {
    groups.insert(0, remaining.substring(remaining.length - 2));
    remaining = remaining.substring(0, remaining.length - 2);
  }
  groups.insert(0, remaining);
  final formatted =
      '${groups.join(',')},${digits.substring(digits.length - 3)}';
  return amount < 0 ? '-$formatted' : formatted;
}

/// Icon from inner SVG paths (viewBox 24, no fill, stroke 1.8, round caps).
Widget _icon(String innerSvgPath, String colorHex, double size) {
  return SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="$colorHex" stroke-width="1.8" stroke-linecap="round" '
    'stroke-linejoin="round">$innerSvgPath</svg>',
    width: size,
    height: size,
  );
}

// Icon paths (from _icons.html)
const String _icWallet =
    '<path d="M3 7a2 2 0 0 1 2-2h13v4"/><path d="M3 7v11a2 2 0 0 0 2 2h14a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5a2 2 0 0 1-2-2z"/><circle cx="16" cy="14" r="1"/>';
const String _icPlus = '<path d="M12 5v14M5 12h14"/>';
const String _icTrophy =
    '<path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/>';
const String _icTicket =
    '<path d="M3 9a2 2 0 0 0 0 6v3h18v-3a2 2 0 0 1 0-6V6H3z"/><path d="M13 6v12" stroke-dasharray="2 2"/>';
const String _icArrow = '<path d="M9 5l7 7-7 7"/>';

// Colors
const Color _white = Colors.white;
const Color _g1 = Color(0xFF4CC9AA);
const Color _g2 = Color(0xFF6EE6C3);
const Color _gd = Color(0xFF1B6F5C);
const Color _muted = Color(0xFF9CA3C7);
const Color _gold = Color(0xFFFBBF24);
const Color _redT = Color(0xFFF87171);
const Color _greenT = Color(0xFF4ADE80);

// Shared gradients ("--glass", "--gbtn")
const LinearGradient _glassGrad = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: <Color>[
    Color.fromRGBO(255, 255, 255, .13),
    Color.fromRGBO(255, 255, 255, .035),
    Color.fromRGBO(255, 255, 255, .07),
  ],
  stops: <double>[0, .45, 1],
  transform: _CssAngle(145),
);
const Color _glassBase = Color.fromRGBO(12, 16, 15, .5);

const LinearGradient _gbtnGrad = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[
    Color.fromRGBO(110, 230, 195, .26),
    Color.fromRGBO(27, 111, 92, .2),
  ],
);
const Color _gbtnBase = Color.fromRGBO(12, 22, 20, .45);
const Color _gbtnBorder = Color.fromRGBO(140, 240, 210, .38);

/// CSS-style angled gradient (0deg = up, 90deg = right, 145deg = down-right).
class _CssAngle extends GradientTransform {
  const _CssAngle(this.deg);
  final double deg;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final th = deg * math.pi / 180;
    final len =
        (bounds.width * math.sin(th)).abs() +
        (bounds.height * math.cos(th)).abs();
    final s = bounds.width == 0 ? 1.0 : len / bounds.width;
    final c = bounds.center;
    return Matrix4.translationValues(c.dx, c.dy, 0) *
        Matrix4.rotationZ(th - math.pi / 2) *
        Matrix4.diagonal3Values(s, 1, 1) *
        Matrix4.translationValues(-c.dx, -c.dy, 0);
  }
}

/// clamp(min, vw, max) like CSS.
double _vw(BuildContext context, double min, double vw, double max) {
  final w = MediaQuery.of(context).size.width * vw / 100;
  return w.clamp(min, max).toDouble();
}

/// Duration that becomes zero when the OS asks for no animations.
Duration _ms(BuildContext context, int ms) {
  return MediaQuery.of(context).disableAnimations
      ? Duration.zero
      : Duration(milliseconds: ms);
}

/// A text line that sits inside a fixed-height line box (CSS inline <small>).
Widget _line(double height, Widget child, [double align = .3]) {
  return SizedBox(
    height: height,
    child: Align(alignment: Alignment(-1, align), child: child),
  );
}

/// Outer shadow that is clipped away inside the box (like CSS box-shadow).
class _Sh {
  const _Sh(this.dy, this.blur, this.color, {this.spread = 0});
  final double dy;
  final double blur;
  final double spread;
  final Color color;
}

class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.r, this.shadows);
  final double r;
  final List<_Sh> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty || size.isEmpty) return;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(r, math.min(size.width, size.height) / 2)),
    );
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rr.outerRect.inflate(400)),
      Path()..addRRect(rr),
    );
    canvas.save();
    canvas.clipPath(outside);
    for (final s in shadows) {
      final paint = Paint()..color = s.color;
      if (s.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
      }
      canvas.drawRRect(rr.shift(Offset(0, s.dy)).inflate(s.spread), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) {
    if (old.r != r || old.shadows.length != shadows.length) return true;
    for (var i = 0; i < shadows.length; i++) {
      final a = old.shadows[i], b = shadows[i];
      if (a.dy != b.dy ||
          a.blur != b.blur ||
          a.spread != b.spread ||
          a.color != b.color) {
        return true;
      }
    }
    return false;
  }
}

/// Inset highlight: `inset 0 1px 0 <color>`.
class _HLPainter extends CustomPainter {
  const _HLPainter(this.r, this.color);
  final double r;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(r, math.min(size.width, size.height) / 2)),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(rr)
      ..addRRect(rr.shift(const Offset(0, 1)));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HLPainter old) => old.r != r || old.color != color;
}

/// Generic glass surface: background colour + gradient, 1px border, inset
/// highlight, clipped outer shadows, optional backdrop blur and clipping.
class _Surface extends StatelessWidget {
  const _Surface({
    this.surfaceKey,
    required this.r,
    this.color,
    this.gradient,
    this.border,
    this.hl,
    this.shadows = const <_Sh>[],
    this.padding,
    this.blur = 0,
    this.clip = false,
    this.child,
  });

  final Key? surfaceKey;
  final double r;
  final Color? color;
  final Gradient? gradient;
  final Color? border;
  final Color? hl;
  final List<_Sh> shadows;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final bool clip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final inner = math.max(r - 1, 0.0);
    Widget c = child ?? const SizedBox.shrink();
    if (padding != null) c = Padding(padding: padding!, child: c);
    if (hl != null) {
      c = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          c,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HLPainter(inner, hl!)),
            ),
          ),
        ],
      );
    }
    if (clip) {
      c = ClipRRect(borderRadius: BorderRadius.circular(inner), child: c);
    }
    Widget box = Container(
      key: surfaceKey,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(r),
        border: border == null ? null : Border.all(color: border!, width: 1),
      ),
      child: c,
    );
    if (blur > 0) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: box,
        ),
      );
    }
    if (shadows.isNotEmpty) {
      box = CustomPaint(painter: _ShadowPainter(r, shadows), child: box);
    }
    return box;
  }
}

/// Tap squeeze (AnimatedScale). 0.98 for cards, 0.93 for buttons.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    this.onTap,
    this.scale = .98,
    this.dur = 200,
    this.onPress,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final int dur;
  final ValueChanged<bool>? onPress;
  final bool enabled;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
    widget.onPress?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: on ? (_) => _set(true) : null,
      onTapUp: on ? (_) => _set(false) : null,
      onTapCancel: on ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (_down && on) ? widget.scale : 1,
        duration: _ms(context, widget.dur),
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}

enum _BV { primary, ghost, violet, paused }

/// `.btn` — primary (green glass), ghost, violet (neutral glass).
class _Btn extends StatelessWidget {
  const _Btn({
    required this.variant,
    required this.onTap,
    required this.label,
    this.leading,
    this.height = 52,
  });

  final _BV variant;
  final VoidCallback? onTap;
  final String label;
  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    Color fg;
    Color border;
    Color base;
    Color hl;
    Gradient grad;
    List<_Sh> sh;
    double blur = 0;
    if (variant == _BV.paused) {
      fg = _white;
      border = rsC(248, 113, 113, .75);
      base = rsC(127, 29, 29, .72);
      grad = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(248, 113, 113, .38),
          Color.fromRGBO(127, 29, 29, .48),
        ],
      );
      hl = rsC(255, 255, 255, .16);
      sh = const <_Sh>[_Sh(4, 12, Color.fromRGBO(127, 29, 29, .3))];
    } else if (variant == _BV.primary) {
      fg = const Color(0xFFEAFFF7);
      border = _gbtnBorder;
      base = _gbtnBase;
      grad = _gbtnGrad;
      hl = rsC(255, 255, 255, .26);
      sh = const <_Sh>[_Sh(6, 18, Color.fromRGBO(0, 0, 0, .35))];
      blur = 18;
    } else if (variant == _BV.ghost) {
      fg = _white;
      border = rsC(255, 255, 255, .18);
      base = rsC(20, 44, 38, .5);
      grad = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(255, 255, 255, .15),
          Color.fromRGBO(255, 255, 255, .04),
        ],
      );
      hl = rsC(255, 255, 255, .2);
      sh = const <_Sh>[_Sh(6, 18, Color.fromRGBO(0, 0, 0, .35))];
      blur = 18;
    } else {
      fg = _white;
      border = rsC(255, 255, 255, .35);
      base = rsC(18, 19, 22, .7);
      grad = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(255, 255, 255, .26),
          Color.fromRGBO(255, 255, 255, .07),
        ],
      );
      hl = rsC(255, 255, 255, .3);
      sh = const <_Sh>[_Sh(6, 18, Color.fromRGBO(0, 0, 0, .45))];
      blur = 18;
    }

    final text = Text(label, style: _t(14, FontWeight.w600, fg));
    final Widget content = leading == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[leading!, const SizedBox(width: 7), text],
          );

    return AnimatedOpacity(
      opacity: onTap == null && variant != _BV.paused ? .5 : 1,
      duration: _ms(context, 250),
      curve: Curves.ease,
      child: _Pressable(
        scale: .93,
        enabled: onTap != null,
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: _Surface(
            r: 999,
            color: base,
            gradient: grad,
            border: border,
            hl: hl,
            shadows: sh,
            blur: blur,
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}

/// `.inp` capsule: "₹" + digits-only field (+ optional trailing widget).
class _Capsule extends StatefulWidget {
  const _Capsule({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.maxLen,
    this.dark = false,
    this.trailing,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final int maxLen;
  final bool dark;
  final Widget? trailing;

  @override
  State<_Capsule> createState() => _CapsuleState();
}

class _CapsuleState extends State<_Capsule> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_Capsule old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final focused = widget.focusNode.hasFocus;
    final bg = dark ? rsC(0, 0, 0, .45) : rsC(255, 255, 255, .05);
    final Color border;
    final Color ring;
    if (dark) {
      border = focused ? rsC(255, 255, 255, .7) : rsC(255, 255, 255, .22);
      ring = focused ? rsC(255, 255, 255, .12) : rsC(255, 255, 255, 0);
    } else {
      border = focused ? rsC(76, 201, 170, .7) : rsC(255, 255, 255, .14);
      ring = focused ? rsC(47, 143, 122, .25) : rsC(47, 143, 122, 0);
    }

    Widget body = AnimatedContainer(
      duration: _ms(context, 250),
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: <Widget>[
                Text(
                  '₹',
                  style: _t(18, FontWeight.w600, rsC(0xCF, 0xE3, 0xDC)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLines: 1,
                    cursorColor: _white,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.maxLen),
                    ],
                    style: _t(16, FontWeight.w500, _white),
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hint,
                      hintStyle: _t(16, FontWeight.w500, rsC(0xA9, 0xB6, 0xB1)),
                    ),
                  ),
                ),
                if (widget.trailing != null) ...<Widget>[
                  const SizedBox(width: 10),
                  widget.trailing!,
                ],
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HLPainter(25, rsC(255, 255, 255, .08)),
              ),
            ),
          ),
        ],
      ),
    );

    if (dark) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: body,
        ),
      );
    }

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: ring),
      duration: _ms(context, 250),
      builder: (context, col, child) {
        return CustomPaint(
          painter: _ShadowPainter(999, <_Sh>[
            _Sh(0, 0, col ?? ring, spread: 3),
          ]),
          child: child,
        );
      },
      child: body,
    );
  }
}

/// Section title (`h2`).
class _H2 extends StatelessWidget {
  const _H2(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[_g1, _gd],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: _t(
                12,
                FontWeight.w600,
                const Color(0xFF9FD9C7),
                ls: 12 * .14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.hint`
class _Hint extends StatelessWidget {
  const _Hint(
    this.text, {
    this.color = const Color(0xFF9AA8A3),
    this.shadow = false,
  });
  final String text;
  final Color color;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    var style = _t(11, FontWeight.w400, color, h: 1.5);
    if (shadow) {
      style = style.copyWith(
        shadows: const <Shadow>[
          Shadow(
            color: Color.fromRGBO(0, 0, 0, .9),
            offset: Offset(0, 1),
            blurRadius: 8,
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, textAlign: TextAlign.center, style: style),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WalletPage
// ---------------------------------------------------------------------------

class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    this.walletChip,
    this.initial,
    this.onTotalChanged,
    this.onPay,
    this.onOpenProfile,
    this.initialPayStatus,
    this.repository,
    this.bottomInset = const EdgeInsets.only(bottom: 100),
  });

  /// Header right widget. Default: simple "₹ 1,250" pill (live total).
  final Widget? walletChip;

  /// null => mock data.
  final WalletState? initial;

  /// Called with the new total whenever the balance changes.
  final ValueChanged<int>? onTotalChanged;

  /// "Add" button. null => mock (700ms, then success / pending approval).
  final Future<PayResult> Function(int amount)? onPay;

  /// UPI "Add" / "Change" link.
  final VoidCallback? onOpenProfile;

  /// 'paid' | 'pending' | 'failed' => toast on open.
  final String? initialPayStatus;
  final WalletRepository? repository;

  /// Space for the outside bottom nav.
  final EdgeInsets bottomInset;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with WidgetsBindingObserver {
  late WalletState _w;
  late final List<WalletTx> _txs;
  final Set<WalletTx> _fresh = <WalletTx>{};
  final Map<WalletTx, DateTime> _born = <WalletTx, DateTime>{};
  Timer? _paymentPollTimer;
  String? _pendingPaymentOrderId;
  bool _checkingPaymentStatus = false;
  bool _appResumed = true;
  int _paymentPollAttempts = 0;
  int _panel = 0;
  String _kind = 'all';

  final GlobalKey<WalletToastState> _toast = GlobalKey<WalletToastState>();
  final GlobalKey<TickOverlayState> _tick = GlobalKey<TickOverlayState>();
  final GlobalKey<AddMoneyPanelState> _add = GlobalKey<AddMoneyPanelState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initial = widget.initial;
    if (initial == null) {
      if (widget.repository != null) {
        _w = WalletState(
          deposited: AuthSession.deposited.value,
          winnings: AuthSession.winnings.value,
          bonus: AuthSession.bonus.value,
          hasUpi: AuthSession.hasUpi.value,
          upi: AuthSession.upi.value,
          dailyLeft: AuthSession.dailyLeft.value,
          paymentMethod: AuthSession.paymentMethod.value,
          limits: WalletLimits(
            minAdd: AuthSession.minAdd.value,
            maxAdd: AuthSession.maxAdd.value,
            minWithdraw: AuthSession.minWithdraw.value,
            dailyLimit: AuthSession.dailyLimit.value,
          ),
        );
      } else {
        final total = AuthSession.walletTotal.value;
        final saved = WalletMock.currentState;
        final delta = total - saved.total;
        var deposited = saved.deposited;
        var winnings = saved.winnings;
        if (delta > 0) {
          deposited += delta;
        } else if (delta < 0) {
          final reduction = -delta;
          final fromDeposit = math.min(deposited, reduction);
          deposited -= fromDeposit;
          winnings = math.max(winnings - reduction + fromDeposit, 0);
        }
        _w = saved.copyWith(
          deposited: deposited,
          winnings: winnings,
          hasUpi: AuthSession.hasUpi.value,
          upi: AuthSession.upi.value,
        );
        WalletMock.currentState = _w;
      }
    } else {
      _w = initial;
      WalletMock.currentState = initial;
      AuthSession.walletTotal.value = initial.total;
    }
    AuthSession.upi.addListener(_syncUpi);
    AuthSession.hasUpi.addListener(_syncUpi);
    widget.onTotalChanged?.call(_w.total);
    _txs = widget.repository == null ? WalletMock.transactions() : <WalletTx>[];
    if (widget.repository != null) {
      unawaited(_refreshWallet());
      unawaited(_loadTransactions());
    }
    final now = DateTime.now();
    for (final t in _txs) {
      if (t.waitLeft != null) _born[t] = now;
    }
    final ps = widget.initialPayStatus;
    if (ps != null && ps.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ps == 'paid') {
          _notify(
            WalletToastType.ok,
            'Payment received',
            'Your wallet is updated.',
          );
        } else if (ps == 'pending') {
          _notify(
            WalletToastType.warn,
            'Payment is being confirmed',
            'Your wallet updates shortly.',
          );
        } else {
          _notify(
            WalletToastType.err,
            'Payment failed',
            'The payment failed or was cancelled.',
          );
        }
      });
    }
  }

  void _syncUpi() {
    if (!mounted) return;
    final upi = AuthSession.upi.value;
    final hasUpi = AuthSession.hasUpi.value;
    if (_w.upi == upi && _w.hasUpi == hasUpi) return;
    setState(() {
      _w = _w.copyWith(upi: upi, hasUpi: hasUpi);
    });
    if (widget.repository == null) WalletMock.currentState = _w;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (_appResumed && _pendingPaymentOrderId != null) {
      unawaited(_checkPaymentStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentPollTimer?.cancel();
    AuthSession.upi.removeListener(_syncUpi);
    AuthSession.hasUpi.removeListener(_syncUpi);
    super.dispose();
  }

  void _notify(WalletToastType type, String title, String text) {
    _toast.currentState?.show(type, title, text);
  }

  String _nowLabel() {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = DateTime.now();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, ${p(h)}:${p(d.minute)} '
        '${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _applyWallet(WalletState w) {
    setState(() => _w = w);
    if (widget.repository == null) WalletMock.currentState = w;
    AuthSession.applyWallet(
      deposited: w.deposited,
      winnings: w.winnings,
      bonus: w.bonus,
      dailyLeft: w.dailyLeft,
      minAdd: w.limits.minAdd,
      maxAdd: w.limits.maxAdd,
      minWithdraw: w.limits.minWithdraw,
      dailyLimit: w.limits.dailyLimit,
      upi: w.upi,
      hasUpi: w.hasUpi,
      paymentMethod: w.paymentMethod,
    );
    widget.onTotalChanged?.call(w.total);
  }

  Future<void> _refreshWallet() async {
    final repository = widget.repository;
    if (repository == null) return;
    try {
      final wallet = await repository.getWallet();
      if (mounted) _applyWallet(wallet);
    } catch (error) {
      if (mounted) {
        _notify(
          WalletToastType.err,
          'Could not refresh wallet',
          _errorText(error),
        );
      }
    }
  }

  Future<void> _loadTransactions() async {
    final repository = widget.repository;
    if (repository == null) return;
    try {
      final txs = await repository.getTransactions();
      if (!mounted) return;
      setState(() {
        _txs
          ..clear()
          ..addAll(txs);
        _fresh.clear();
        _born.clear();
      });
    } catch (error) {
      if (mounted) {
        _notify(
          WalletToastType.err,
          'Could not load transactions',
          _errorText(error),
        );
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([_refreshWallet(), _loadTransactions()]);
  }

  String _errorText(Object error) =>
      error is ApiAuthException ? error.message : 'Network problem. Try again.';

  void _addTx(WalletTx t) {
    setState(() {
      _txs.insert(0, t);
      _fresh.add(t);
      if (t.waitLeft != null) _born[t] = DateTime.now();
    });
  }

  void _select(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _panel = i);
    if (i == 2) unawaited(_loadTransactions());
  }

  void _goAdd() {
    _select(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _add.currentState?.focusAmount();
    });
  }

  // ---- Add money ----
  Future<void> _submitAdd(int a) async {
    if (_w.paymentMethod != 'gateway') {
      _notify(
        WalletToastType.warn,
        _w.paymentMethod == 'off' ? 'Adding money is paused' : 'Coming soon',
        _w.paymentMethod == 'off'
            ? 'Adding money is currently disabled.'
            : 'Manual payments are not available yet.',
      );
      return;
    }
    final repository = widget.repository;
    if (repository != null) {
      if (_pendingPaymentOrderId != null) {
        _notify(
          WalletToastType.warn,
          'Payment is being confirmed',
          'Please wait for the current payment to finish before starting another.',
        );
        return;
      }
      try {
        final order = await repository.createPaymentOrder(a);
        if (!mounted) return;
        _pendingPaymentOrderId = order.orderId;
        final launched = await launchUrl(
          Uri.parse(order.paymentUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          _stopPaymentPolling();
          throw const ApiAuthException(
            message: 'Could not open the payment page. Please try again.',
          );
        }
        _startPaymentPolling();
        unawaited(_checkPaymentStatus());
      } catch (error) {
        _stopPaymentPolling();
        if (mounted) {
          _notify(
            WalletToastType.err,
            'Could not start payment',
            _errorText(error),
          );
        }
      }
      return;
    }

    PayResult res;
    try {
      res = await (widget.onPay ?? WalletMock.pay)(a);
    } catch (error) {
      res = PayResult.failure(_errorText(error));
    }
    if (!mounted) return;
    if (!res.ok) {
      if (res.cancelled) {
        _notify(
          WalletToastType.warn,
          'Payment cancelled',
          'No money was added to your wallet.',
        );
      } else {
        _notify(
          WalletToastType.err,
          'Payment failed',
          res.error ?? 'Something went wrong. Try again.',
        );
      }
      return;
    }
    if (res.wallet != null) _applyWallet(res.wallet!);
    _addTx(
      res.tx ??
          WalletTx(
            kind: 'added',
            title: 'Money added',
            date: _nowLabel(),
            amt: inr(a),
            dir: 'in',
            status: 'pending',
            waitLeft: 14400,
          ),
    );
    _notify(
      WalletToastType.ok,
      'Sent for approval',
      'Your wallet updates once we verify the payment.',
    );
  }

  void _startPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollAttempts = 0;
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pendingPaymentOrderId == null) {
        timer.cancel();
        return;
      }
      _paymentPollAttempts++;
      if (_paymentPollAttempts > 60) {
        _stopPaymentPolling();
        if (mounted) {
          _notify(
            WalletToastType.warn,
            'Payment confirmation is taking longer',
            'Check your wallet again shortly. Successful payments are credited automatically.',
          );
        }
        return;
      }
      if (_appResumed) unawaited(_checkPaymentStatus());
    });
  }

  void _stopPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    _pendingPaymentOrderId = null;
    _checkingPaymentStatus = false;
  }

  Future<void> _checkPaymentStatus() async {
    final repository = widget.repository;
    final orderId = _pendingPaymentOrderId;
    if (repository == null || orderId == null || _checkingPaymentStatus) return;
    _checkingPaymentStatus = true;
    try {
      final result = await repository.checkPaymentOrder(orderId);
      if (!mounted || _pendingPaymentOrderId != orderId) return;
      if (result.status == 'paid') {
        _stopPaymentPolling();
        if (result.wallet != null) _applyWallet(result.wallet!);
        await _refreshAll();
        if (mounted) {
          _notify(
            WalletToastType.ok,
            'Payment received',
            'Your wallet has been updated.',
          );
        }
      } else if (result.status == 'failed' ||
          result.status == 'create_failed') {
        _stopPaymentPolling();
        _notify(
          WalletToastType.err,
          'Payment failed',
          'No money was added to your wallet.',
        );
      }
    } catch (_) {
      // Keep polling; transient network errors must not be shown as payment failure.
    } finally {
      _checkingPaymentStatus = false;
    }
  }

  // ---- Withdraw ----
  Future<bool> _submitWithdraw(int a) async {
    final repository = widget.repository;
    if (repository != null) {
      try {
        final result = await repository.withdraw(a);
        if (!mounted) return false;
        _applyWallet(result.wallet);
        _addTx(result.tx);
        unawaited(_refreshAll());
        _notify(
          WalletToastType.ok,
          'Withdrawal requested',
          '₹${result.tx.amt} is pending. We will pay it to your UPI ID.',
        );
        return true;
      } catch (error) {
        if (mounted) {
          _notify(WalletToastType.err, 'Withdrawal failed', _errorText(error));
        }
        return false;
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return false;
    _applyWallet(
      _w.copyWith(
        winnings: _w.winnings - a,
        dailyLeft: math.max(_w.dailyLeft - a, 0),
      ),
    );
    final tx = WalletTx(
      kind: 'withdraw',
      title: 'Withdrawal requested',
      date: _nowLabel(),
      amt: inr(a),
      dir: 'out',
      status: 'pending',
    );
    _addTx(tx);
    _notify(
      WalletToastType.ok,
      'Withdrawal requested',
      '₹${tx.amt} is pending. We will pay it to your UPI ID.',
    );
    return true;
  }

  // ---- Winnings -> deposit ----
  Future<bool> _submitMove(int a) async {
    final repository = widget.repository;
    if (repository != null) {
      try {
        final result = await repository.winningsToDeposit(a);
        if (!mounted) return false;
        _applyWallet(result.wallet);
        _addTx(result.tx);
        unawaited(_refreshAll());
        _tick.currentState?.show();
        _notify(
          WalletToastType.ok,
          'Winnings moved',
          '₹${result.tx.amt} is now in your deposit balance.',
        );
        return true;
      } catch (error) {
        if (mounted) {
          _notify(
            WalletToastType.err,
            'Could not move winnings',
            _errorText(error),
          );
        }
        return false;
      }
    }

    _applyWallet(
      _w.copyWith(winnings: _w.winnings - a, deposited: _w.deposited + a),
    );
    _addTx(
      WalletTx(
        kind: 'move',
        title: 'Winnings moved to deposit',
        date: _nowLabel(),
        amt: inr(a),
        dir: 'in',
        status: 'success',
      ),
    );
    _tick.currentState?.show();
    return true;
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Wallet',
                style: _t(
                  _vw(context, 18, 5, 22),
                  FontWeight.w700,
                  _white,
                  h: 1.15,
                ),
              ),
              Text(
                'Add • Play • Withdraw',
                maxLines: 1,
                softWrap: false,
                style: _t(11, FontWeight.w400, _muted, h: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        widget.walletChip ??
            WalletChip(balanceListenable: AuthSession.walletTotal),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final inset = widget.bottomInset;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                color: _g2,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          14 + inset.left,
                          14 + mq.padding.top + inset.top,
                          14 + inset.right,
                          inset.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            RsIn(delay: 0, child: _header(context)),
                            RsIn(
                              delay: .05,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: BalanceCard(
                                  total: _w.total,
                                  deposited: _w.deposited,
                                  winnings: _w.winnings,
                                ),
                              ),
                            ),
                            RsIn(
                              delay: .1,
                              child: WalletSwitch(
                                selected: _panel,
                                onSelect: _select,
                              ),
                            ),
                            RsIn(
                              delay: .14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Offstage(
                                    offstage: _panel != 0,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        AddMoneyPanel(
                                          key: _add,
                                          notify: _notify,
                                          onSubmit: _submitAdd,
                                          minAdd: _w.limits.minAdd,
                                          maxAdd: _w.limits.maxAdd,
                                          paymentMethod: _w.paymentMethod,
                                        ),
                                        const SizedBox(height: 14),
                                        MoveToDepositBox(
                                          winnings: _w.winnings,
                                          notify: _notify,
                                          onMove: _submitMove,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Offstage(
                                    offstage: _panel != 1,
                                    child: WithdrawPanel(
                                      wallet: _w,
                                      notify: _notify,
                                      onSubmit: _submitWithdraw,
                                      onOpenProfile: widget.onOpenProfile,
                                    ),
                                  ),
                                  Offstage(
                                    offstage: _panel != 2,
                                    child: TransactionsPanel(
                                      txs: _txs,
                                      fresh: _fresh,
                                      born: _born,
                                      kind: _kind,
                                      active: _panel == 2,
                                      onKind: (k) => setState(() => _kind = k),
                                      onAddMoney: _goAdd,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          WalletToast(key: _toast),
          TickOverlay(key: _tick),
        ],
      ),
    );
  }
}
