import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../core/auth/api_client.dart';
import '../core/auth/auth_repository.dart';
import '../core/notifications/app_notifications.dart';
import '../core/payment_deep_links.dart';
import '../core/ui_kit.dart';

// ============================================================
//  Helpers (aage ke pages me bhi yahi pattern use hoga)
// ============================================================

const String _googleSvg =
    r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.27-4.74 3.27-8.1z"/>
<path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84A11 11 0 0 0 12 23z"/>
<path fill="#FBBC05" d="M5.84 14.1a6.6 6.6 0 0 1 0-4.2V7.06H2.18a11 11 0 0 0 0 9.88l3.66-2.84z"/>
<path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1A11 11 0 0 0 2.18 7.06l3.66 2.84C6.71 7.31 9.14 5.38 12 5.38z"/>
</svg>''';

// ============================================================
//  Background painters
// ============================================================
class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rx = size.width * .75;
    final ry = size.height;
    canvas.save();
    canvas.translate(size.width / 2, 0);
    canvas.scale(1, ry / rx);
    final r = Rect.fromCircle(center: Offset.zero, radius: rx);
    final p = Paint()
      ..shader = RadialGradient(
        colors: [c(44, 150, 124, .55), c(14, 64, 53, .28), c(0, 0, 0, 0)],
        stops: const [0, .45, .78],
      ).createShader(r);
    canvas.drawRect(
      Rect.fromLTRB(-size.width / 2, 0, size.width / 2, size.height * rx / ry),
      p,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ============================================================
//  Login page
// ============================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialMessage});
  final String? initialMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _scroll = ScrollController();
  final _contactKey = GlobalKey();

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);
  late final AnimationController _spark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..forward();
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => Navigator.pushNamed(context, '/terms');
  late final TapGestureRecognizer _refundTap = TapGestureRecognizer()
    ..onTap = () => Navigator.pushNamed(context, '/refund-policy');

  bool _signup = false;
  bool _busy = false;
  bool _showPass = false;
  bool _intro = false;
  String _msg = '';
  bool _msgOk = false;
  String _wmText = 'LOGIN';
  double _wmOpacity = 1;
  Timer? _wmTimer;

  @override
  void initState() {
    super.initState();
    _msg = widget.initialMessage ?? '';
    _loadIntro();
  }

  Future<void> _loadIntro() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!(p.getBool('rs_intro_seen') ?? false) && mounted) {
        setState(() => _intro = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _wmTimer?.cancel();
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _scroll.dispose();
    _enter.dispose();
    _flow.dispose();
    _spark.dispose();
    _flash.dispose();
    _termsTap.dispose();
    _refundTap.dispose();
    super.dispose();
  }

  void _setMode(bool signup) {
    if (_signup == signup) return;
    setState(() {
      _signup = signup;
      _msg = '';
      _wmOpacity = 0;
    });
    _spark.forward(from: 0);
    _wmTimer?.cancel();
    _wmTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _wmText = signup ? 'JOIN' : 'LOGIN';
        _wmOpacity = 1;
      });
    });
  }

  void _say(String t, {bool ok = false}) => setState(() {
    _msg = t;
    _msgOk = ok;
  });

  Future<void> _submit() async {
    final email = _email.text.trim(),
        pass = _pass.text,
        name = _name.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      return _say('Enter a valid email address.');
    }
    if (pass.length < 6) return _say('Password must be at least 6 characters.');
    if (_signup && name.isEmpty) return _say('Enter your name.');
    await _runAuth(
      () => _signup
          ? AuthRepository().signUpWithEmail(name, email, pass)
          : AuthRepository().signInWithEmail(email, pass),
    );
  }

  Future<void> _googleSignIn() => _runAuth(AuthRepository().signInWithGoogle);

  Future<void> _runAuth(Future<void> Function() authenticate) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _msg = '';
    });
    try {
      await authenticate();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppNotifications.consumePendingTap();
        PaymentDeepLinks.consumePending();
      });
    } on FirebaseAuthException catch (error) {
      if (mounted) _say(_firebaseError(error));
    } on ApiAuthException catch (error) {
      if (mounted) _say(error.message);
    } catch (error) {
      if (mounted) {
        _say(
          error is StateError
              ? 'Sign-in could not be completed securely. Please try again.'
              : 'Unable to sign in. Please check your details and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _firebaseError(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Password must be at least 6 characters.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Email or password is incorrect.',
    'network-request-failed' =>
      'Network problem. Check your internet and try again.',
    'too-many-requests' => 'Too many attempts. Please wait and try again.',
    'account-exists-with-different-credential' =>
      'An account already exists with another sign-in method.',
    _ => error.message ?? 'Unable to sign in. Please try again.',
  };

  void _skip() {
    if (!kDebugMode) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  // ---------- forgot password popup ----------
  void _openForgot() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, a, b) => _ForgotPopup(
        onClose: () => Navigator.pop(ctx),
        onGo: () {
          Navigator.pop(ctx);
          _goContact();
        },
      ),
      transitionBuilder: (ctx, a, _, child) {
        final s = (14 * a.value).clamp(.01, 14).toDouble();
        final curved = CurvedAnimation(parent: a, curve: kEase);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: s, sigmaY: s),
                  child: Container(color: c(0, 0, 0, .5 * a.value)),
                ),
              ),
            ),
            FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .04),
                  end: Offset.zero,
                ).animate(curved),
                child: ScaleTransition(
                  scale: Tween(begin: .96, end: 1.0).animate(curved),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _goContact() {
    final ctx = _contactKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: .5,
      );
    }
    _flash.forward(from: 0);
  }

  // ============================================================
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final vh = mq.size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 620,
                  child: IgnorePointer(
                    child: CustomPaint(painter: _GlowPainter()),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 480, minHeight: vh),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          18 + mq.padding.top,
                          16,
                          30 + mq.padding.bottom,
                        ),
                        child: Column(
                          children: [
                            _brand(),
                            _card(),
                            _legal(),
                            const Spacer(),
                            _blocks(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (kDebugMode)
            Positioned(
              top: mq.padding.top + 10,
              right: 14,
              child: Pressable(
                onTap: _skip,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: c(0, 0, 0, .45),
                    border: Border.all(color: c(255, 255, 255, .3)),
                  ),
                  child: Text(
                    'Skip (testing)',
                    style: t(11, FontWeight.w600, Colors.white),
                  ),
                ),
              ),
            ),

          if (_intro)
            Positioned.fill(
              child: IntroOverlay(onDone: () => setState(() => _intro = false)),
            ),
        ],
      ),
    );
  }

  // ---------- brand ----------
  Widget _brand() {
    final wmSize = (MediaQuery.of(context).size.width * .32)
        .clamp(96.0, 150.0)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: SizedBox(
        width: double.infinity,
        height: 36,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // watermark
            Positioned(
              top: (36 - wmSize * 1.5) / 2,
              left: 0,
              right: 0,
              height: wmSize * 1.5,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _enter,
                  builder: (_, _) {
                    final v = Interval(
                      0,
                      .9,
                      curve: Curves.easeOut,
                    ).transform(_enter.value);
                    return Opacity(
                      opacity: v,
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (r) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.transparent],
                          stops: [.25, .92],
                        ).createShader(r),
                        child: AnimatedOpacity(
                          opacity: _wmOpacity,
                          duration: const Duration(milliseconds: 250),
                          child: Center(
                            child: OverflowBox(
                              maxWidth: double.infinity,
                              maxHeight: wmSize * 1.5,
                              child: Text(
                                _wmText,
                                softWrap: false,
                                style: t(
                                  wmSize,
                                  FontWeight.w700,
                                  c(255, 255, 255, .1),
                                  ls: -.03 * wmSize,
                                  h: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // name
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _enter,
                builder: (_, _) {
                  final v = Interval(
                    0,
                    .67,
                    curve: kEase,
                  ).transform(_enter.value);
                  final blur = 8 * (1 - v);
                  Widget w = Transform.translate(
                    offset: Offset(0, 18 * (1 - v)),
                    child: Transform.scale(
                      scale: .94 + .06 * v,
                      child: Center(
                        child: Text(
                          'RIVALON',
                          style: t(
                            30,
                            FontWeight.w700,
                            Colors.white,
                            ls: 30 * (.34 - .26 * v),
                          ),
                        ),
                      ),
                    ),
                  );
                  if (blur > .1) {
                    w = ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: w,
                    );
                  }
                  return Opacity(opacity: v.clamp(0.0, 1.0), child: w);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- card ----------
  Widget _card() {
    final cardBase = c(10, 10, 10);
    final btnBase = Color.alphaBlend(c(12, 22, 20, .45), cardBase);
    final dkBase = c(16, 23, 21);
    return Container(
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(c(255, 255, 255, .06), cardBase),
            Color.alphaBlend(c(255, 255, 255, .015), cardBase),
          ],
        ),
        border: Border.all(color: c(255, 255, 255, .1)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _seg(),
              _GlassField(
                controller: _name,
                hint: 'Name',
                fold: !_signup,
                type: TextInputType.name,
                caps: TextCapitalization.words,
                maxLength: 30,
                hints: const [AutofillHints.name],
              ),
              _GlassField(
                controller: _email,
                hint: 'Email',
                type: TextInputType.emailAddress,
                hints: const [AutofillHints.email],
              ),
              _GlassField(
                controller: _pass,
                hint: 'Password',
                obscure: !_showPass,
                hints: [
                  _signup ? AutofillHints.newPassword : AutofillHints.password,
                ],
                trailing: GestureDetector(
                  onTap: () => setState(() => _showPass = !_showPass),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                    child: Text(
                      _showPass ? 'Hide' : 'Show',
                      style: t(12, FontWeight.w600, c(159, 232, 206)),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 18),
                    child: Text(
                      _msg,
                      style: t(
                        12,
                        FontWeight.w400,
                        _msgOk ? c(74, 222, 128) : c(248, 113, 113),
                        h: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              // main button
              Pressable(
                onTap: _busy ? null : _submit,
                child: Opacity(
                  opacity: _busy ? .55 : 1,
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.alphaBlend(c(110, 230, 195, .26), btnBase),
                          Color.alphaBlend(c(27, 111, 92, .2), btnBase),
                        ],
                      ),
                      border: Border.all(color: c(140, 240, 210, .38)),
                      boxShadow: [
                        BoxShadow(
                          color: c(0, 0, 0, .35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      _signup ? 'Create account' : 'Log in',
                      style: t(16, FontWeight.w600, Colors.white).copyWith(
                        shadows: [
                          Shadow(
                            color: c(0, 50, 36, .5),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // forgot (hides on signup)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: kEase,
                height: _signup ? 0 : 48,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: AnimatedOpacity(
                  opacity: _signup ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Center(
                    child: GestureDetector(
                      onTap: _signup ? null : _openForgot,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Forgot password?',
                          style: t(13, FontWeight.w400, c(195, 205, 201))
                              .copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: c(195, 205, 201),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // or
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(child: _orLine()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: t(12, FontWeight.w400, c(154, 168, 163)),
                      ),
                    ),
                    Expanded(child: _orLine()),
                  ],
                ),
              ),
              // google
              Pressable(
                scale: .985,
                onTap: _busy ? null : _googleSignIn,
                child: Opacity(
                  opacity: _busy ? .55 : 1,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.alphaBlend(c(76, 201, 170, .12), dkBase),
                          Color.alphaBlend(c(12, 22, 20, .72), dkBase),
                        ],
                        stops: const [0, .6],
                      ),
                      border: Border.all(color: c(110, 230, 195, .22)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.string(_googleSvg, width: 20, height: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Continue with Google',
                          style: t(16, FontWeight.w600, c(234, 255, 247)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // loading circle over the card
          if (_busy)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: c(0, 0, 0, .6),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: c(76, 201, 170),
                      backgroundColor: c(255, 255, 255, .2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orLine() => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          c(110, 230, 195, 0),
          c(110, 230, 195, .3),
          c(110, 230, 195, 0),
        ],
      ),
    ),
  );

  // ---------- Log in / Sign up glass switch ----------
  Widget _seg() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c(255, 255, 255, .13), c(255, 255, 255, .04)],
        ),
        border: Border.all(color: c(255, 255, 255, .18)),
      ),
      child: SizedBox(
        height: 46,
        child: LayoutBuilder(
          builder: (context, box) {
            final tw = (box.maxWidth - 6) / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: kEase,
                  left: _signup ? tw + 6 : 0,
                  top: 0,
                  bottom: 0,
                  width: tw,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: const Alignment(-.44, -1),
                        radius: 1.3,
                        colors: [
                          c(93, 240, 197, .36),
                          c(34, 176, 138, .22),
                          c(11, 107, 82, .35),
                        ],
                        stops: const [0, .42, 1],
                      ),
                      border: Border.all(color: c(165, 255, 228, .45)),
                      boxShadow: [
                        BoxShadow(
                          color: c(27, 111, 92, .2),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _segTab('Log in', !_signup, () => _setMode(false)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _segTab('Sign up', _signup, () => _setMode(true)),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _segTab(String label, bool on, VoidCallback tap) {
    return Pressable(
      onTap: tap,
      child: AnimatedScale(
        scale: on ? 1.04 : 1,
        duration: const Duration(milliseconds: 350),
        curve: kEase,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (on)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _spark,
                      builder: (_, _) {
                        final t = _spark.value;
                        final op = t < .2
                            ? t / .2
                            : (t < .75
                                  ? 1 - (t - .2) / .55 * .3
                                  : .7 * (1 - (t - .75) / .25));
                        return Opacity(
                          opacity: op.clamp(0.0, 1.0),
                          child: FractionalTranslation(
                            translation: Offset(-1.3 + 2.6 * t, 0),
                            child: Transform(
                              transform: Matrix4.skewX(-.314),
                              alignment: Alignment.center,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      c(220, 255, 244, 0),
                                      c(220, 255, 244, .55),
                                      c(110, 230, 195, .3),
                                      c(110, 230, 195, 0),
                                    ],
                                    stops: const [.25, .48, .54, .76],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 350),
                  curve: kEase,
                  style: on
                      ? t(16, FontWeight.w600, Colors.white).copyWith(
                          shadows: [
                            Shadow(
                              color: c(110, 230, 195, .5),
                              blurRadius: 12,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        )
                      : t(14, FontWeight.w500, c(174, 187, 182)),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- legal ----------
  Widget _legal() {
    final base = t(11, FontWeight.w400, c(141, 154, 149), h: 1.7);
    final link = t(11, FontWeight.w400, c(195, 205, 201), h: 1.7).copyWith(
      decoration: TextDecoration.underline,
      decorationColor: c(195, 205, 201),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'By continuing you agree to the '),
            TextSpan(text: 'Terms', style: link, recognizer: _termsTap),
            const TextSpan(text: ' of RIVALON.\n'),
            TextSpan(text: 'Refunds', style: link, recognizer: _refundTap),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ---------- privacy + contact blocks ----------
  Widget _blocks() {
    return Column(
      children: [
        _InfoBlock(
          iconInner:
              '<path d="M12 3l8 3v6c0 4.5-3.2 7.8-8 9-4.8-1.2-8-4.5-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
          title: 'Privacy Policy',
          sub: 'How we use and protect your data',
          enter: _enter,
          enterInterval: const Interval(.083, .583, curve: kEase),
          flow: _flow,
          onTap: () => Navigator.pushNamed(context, '/privacy'),
        ),
        const SizedBox(height: 12),
        _InfoBlock(
          key: _contactKey,
          iconInner:
              '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 .9-1 1.7M12 17h.01"/>',
          title: 'Contact us',
          sub: 'Help with your account or payments',
          enter: _enter,
          enterInterval: const Interval(.167, .667, curve: kEase),
          flow: _flow,
          flash: _flash,
          onTap: () =>
              Navigator.of(context, rootNavigator: true).pushNamed('/contact'),
        ),
      ],
    );
  }
}

// ============================================================
//  Glass text field
// ============================================================
class _GlassField extends StatefulWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.trailing,
    this.type,
    this.fold = false,
    this.hints,
    this.maxLength,
    this.caps = TextCapitalization.none,
  });
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? type;
  final bool fold;
  final Iterable<String>? hints;
  final int? maxLength;
  final TextCapitalization caps;

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  final _f = FocusNode();
  @override
  void initState() {
    super.initState();
    _f.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = _f.hasFocus && !widget.fold;
    final fold = widget.fold;
    final base = c(16, 23, 21);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: kEase,
      height: fold ? 0 : 60,
      margin: EdgeInsets.only(bottom: fold ? 0 : 10),
      padding: EdgeInsets.symmetric(horizontal: fold ? 0 : 20),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(c(76, 201, 170, focus ? .16 : .11), base),
            Color.alphaBlend(c(12, 22, 20, focus ? .72 : .62), base),
          ],
          stops: const [0, .6],
        ),
        border: Border.all(
          color: fold
              ? c(110, 230, 195, 0)
              : c(110, 230, 195, focus ? .58 : .18),
        ),
        boxShadow: focus
            ? [
                BoxShadow(
                  color: c(47, 143, 122, .2),
                  spreadRadius: 3,
                  blurRadius: 0,
                ),
              ]
            : const [],
      ),
      child: ExcludeFocus(
        excluding: fold,
        child: IgnorePointer(
          ignoring: fold,
          child: AnimatedOpacity(
            opacity: fold ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _f,
                    obscureText: widget.obscure,
                    keyboardType: widget.type,
                    textCapitalization: widget.caps,
                    autocorrect: false,
                    enableSuggestions: !widget.obscure,
                    autofillHints: widget.hints,
                    cursorColor: c(110, 230, 195),
                    style: t(15, FontWeight.w500, Colors.white),
                    inputFormatters: widget.maxLength == null
                        ? null
                        : [LengthLimitingTextInputFormatter(widget.maxLength)],
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: widget.hint,
                      hintStyle: t(15, FontWeight.w500, c(180, 192, 187)),
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  Privacy / Contact glowing block
// ============================================================
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    super.key,
    required this.iconInner,
    required this.title,
    required this.sub,
    required this.enter,
    required this.enterInterval,
    required this.flow,
    required this.onTap,
    this.flash,
  });
  final String iconInner, title, sub;
  final Animation<double> enter, flow;
  final Interval enterInterval;
  final Animation<double>? flash;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([enter, flow, ?flash]),
      builder: (_, _) {
        final v = enterInterval.transform(enter.value);
        final p = Curves.easeInOut.transform(flow.value);
        final begin = -1 - 2.8 * p;
        final f = flash?.value ?? 0;
        final fo = f <= 0 ? 0.0 : (f < .35 ? f / .35 : 1 - (f - .35) / .65);
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - v)),
            child: Pressable(
              scale: .985,
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: c(76, 201, 170, .22 * fo),
                  border: Border.all(
                    color: c(130, 240, 205, .9 * fo),
                    width: 2,
                  ),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment(begin, 0),
                    end: Alignment(begin + 4.8, 0),
                    colors: [
                      c(20, 96, 78, .6),
                      c(6, 26, 22, .92),
                      c(40, 140, 115, .5),
                    ],
                    stops: const [0, .42, 1],
                  ),
                  border: Border.all(color: c(76, 201, 170, .32)),
                  boxShadow: [
                    BoxShadow(color: c(44, 150, 124, .14), blurRadius: 26),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c(110, 230, 195, .4)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [c(76, 201, 170, .26), c(76, 201, 170, .06)],
                        ),
                      ),
                      child: svgIcon(iconInner, '#c4f7e6', 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: t(15, FontWeight.w600, Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            style: t(12, FontWeight.w400, c(207, 232, 223)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF36B898), Color(0xFF1B6F5C)],
                        ),
                        boxShadow: [
                          BoxShadow(color: c(54, 184, 152, .4), blurRadius: 16),
                        ],
                      ),
                      child: svgIcon(
                        '<path d="M7 17L17 7M8 7h9v9"/>',
                        '#ffffff',
                        18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
//  Forgot password popup
// ============================================================
class _ForgotPopup extends StatelessWidget {
  const _ForgotPopup({required this.onClose, required this.onGo});
  final VoidCallback onClose, onGo;

  @override
  Widget build(BuildContext context) {
    final base = Color.alphaBlend(c(12, 22, 20, .45), c(10, 10, 10));
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: c(0, 0, 0, .55),
                    blurRadius: 60,
                    offset: const Offset(0, 24),
                  ),
                  BoxShadow(color: c(44, 150, 124, .3), blurRadius: 44),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [c(255, 255, 255, .2), c(255, 255, 255, .06)],
                      ),
                      border: Border.all(color: c(255, 255, 255, .3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: c(255, 255, 255, .14),
                            border: Border.all(color: c(255, 255, 255, .25)),
                          ),
                          child: svgIcon(
                            '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
                            '#ffffff',
                            26,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Forgot your password?',
                          textAlign: TextAlign.center,
                          style: t(19, FontWeight.w600, Colors.white, h: 1.25),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
                          child: Text.rich(
                            TextSpan(
                              style: t(
                                13,
                                FontWeight.w400,
                                c(226, 235, 231),
                                h: 1.6,
                              ),
                              children: [
                                const TextSpan(text: 'Please tap '),
                                TextSpan(
                                  text: 'Contact us',
                                  style: t(
                                    13,
                                    FontWeight.w700,
                                    c(226, 235, 231),
                                    h: 1.6,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      ' shown at the bottom of this page and contact us from there. We will help you get back into your account.',
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Pressable(
                          onTap: onGo,
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color.alphaBlend(c(110, 230, 195, .26), base),
                                  Color.alphaBlend(c(27, 111, 92, .2), base),
                                ],
                              ),
                              border: Border.all(color: c(140, 240, 210, .38)),
                            ),
                            child: Text(
                              'Go to Contact',
                              style: t(15, FontWeight.w600, Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Pressable(
                          onTap: onClose,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            child: Text(
                              'Close',
                              style: t(15, FontWeight.w500, c(226, 235, 231)),
                            ),
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
    );
  }
}

// ============================================================
//  Intro video (sirf pehli baar, sound ke sath, Skip button)
// ============================================================
class IntroOverlay extends StatefulWidget {
  const IntroOverlay({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay>
    with SingleTickerProviderStateMixin {
  late final VideoPlayerController _v = VideoPlayerController.asset(
    'assets/video/intro.mp4',
  );
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  bool _ready = false, _ending = false, _closed = false, _fade = false;
  Timer? _volTimer;

  Future<void> _mark() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('rs_intro_seen', true);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _v.initialize();
      if (!mounted) return;
      await _v.setVolume(1);
      setState(() => _ready = true);
      _v.addListener(_tick);
      await _v.play();
      await _mark();
    } catch (_) {
      _close();
    }
  }

  void _tick() {
    final val = _v.value;
    if (val.hasError) return _close();
    final d = val.duration, p = val.position;
    if (d.inMilliseconds > 2000 && (d - p).inMilliseconds <= 1500) _finish();
    if (d.inMilliseconds > 0 && p >= d) _close();
  }

  void _finish() {
    if (_ending || _closed) return;
    setState(() => _ending = true);
    _light.forward();
    var n = 0;
    _volTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      n++;
      _v.setVolume((1 - n / 12).clamp(0.0, 1.0));
      if (n >= 12) t.cancel();
    });
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _fade = true);
    });
    Timer(const Duration(milliseconds: 1500), _close);
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _mark();
    if (_v.value.isInitialized) _v.pause();
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _volTimer?.cancel();
    _v.removeListener(_tick);
    _v.dispose();
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return AnimatedOpacity(
      opacity: _fade ? 0 : 1,
      duration: const Duration(milliseconds: 600),
      child: IgnorePointer(
        ignoring: _fade,
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _v.value.size.width,
                    height: _v.value.size.height,
                    child: VideoPlayer(_v),
                  ),
                ),
              // white light that grows from the center
              AnimatedBuilder(
                animation: _light,
                builder: (_, _) {
                  final s = const Cubic(.5, 0, .3, 1).transform(_light.value);
                  final big = mq.size.longestSide * 2;
                  return IgnorePointer(
                    child: OverflowBox(
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform.scale(
                        scale: s,
                        child: Container(
                          width: big,
                          height: big,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white,
                                Colors.white,
                                Color(0x00FFFFFF),
                              ],
                              stops: [0, .45, .7],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (!_ending)
                Positioned(
                  top: mq.padding.top + 14,
                  right: 14,
                  child: Pressable(
                    onTap: _close,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: c(0, 0, 0, .45),
                            border: Border.all(color: c(255, 255, 255, .35)),
                          ),
                          child: Text(
                            'Skip',
                            style: t(13, FontWeight.w600, Colors.white),
                          ),
                        ),
                      ),
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
