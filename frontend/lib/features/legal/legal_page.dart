import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui_kit.dart';

// ============================================================
//  Static values (Jinja -> constants)
// ============================================================
const String _email = 'rivalon.smash@gmail.com';
const String _gmailUrl =
    'https://mail.google.com/mail/?view=cm&fs=1&to=rivalon.smash%40gmail.com&su=RIVALON%20support';

const List<String> _tabLabels = ['Terms', 'Privacy', 'Refunds', 'Contact'];
// legal.html me titles dict nahi tha, isliye ye default titles hain. Apne Flask dict se alag ho to yahan badlo.
const List<String> _titles = [
  'Terms',
  'Privacy Policy',
  'Refund Policy',
  'Contact Us',
];

/// CSS me .tab{overflow:hidden} hai, isliye pulse ka bahar wala glow wahan clip ho jata hai.
/// true karoge to glow tab ke bahar phailta dikhega (spec ke hisaab se).
const bool _pulseGlowOutside = false;

// ============================================================
//  Background (login page se copy)
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

/// CSS `inset 0 1px 0 <color>` (top inner highlight)
class _InsetHi extends CustomPainter {
  _InsetHi(this.radius, this.color);
  final double radius;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final a = Path()..addRRect(rr);
    final b = Path()..addRRect(rr.shift(const Offset(0, 1)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, a, b),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _InsetHi old) =>
      old.radius != radius || old.color != color;
}

/// CSS linear-gradient(<deg>) ko Flutter gradient me badalta hai (box size ke hisaab se)
LinearGradient _cssGrad(
  double deg,
  Size s,
  List<Color> colors,
  List<double> stops,
) {
  final a = deg * pi / 180;
  final dx = sin(a), dy = -cos(a);
  final w = max(s.width, 1.0), h = max(s.height, 1.0);
  final len = (w * dx).abs() + (h * dy).abs();
  final hx = dx * len / 2, hy = dy * len / 2;
  return LinearGradient(
    begin: Alignment(-hx / (w / 2), -hy / (h / 2)),
    end: Alignment(hx / (w / 2), hy / (h / 2)),
    colors: colors,
    stops: stops,
  );
}

// ============================================================
//  Content (legal.html se word-to-word)
// ============================================================
// Markup: **bold**   {email} = tappable mailto link
abstract class _Blk {
  const _Blk();
}

class _Upd extends _Blk {
  const _Upd(this.text);
  final String text;
}

class _Notice extends _Blk {
  const _Notice(this.title, this.paras);
  final String title;
  final List<String> paras; // last one = red "stop" paragraph
}

class _H2 extends _Blk {
  const _H2(this.text);
  final String text;
}

class _P extends _Blk {
  const _P(this.text);
  final String text;
}

class _Ul extends _Blk {
  const _Ul(this.items);
  final List<String> items;
}

class _Cbox extends _Blk {
  const _Cbox();
}

const List<_Blk> _terms = [
  _Upd('Last updated: 28 Oct 2026'),
  _Notice('Important: please read this before you log in', [
    'By logging in or creating an account on RIVALON, you confirm that you have read and agree to these Terms, the Privacy Policy and the Refund policy.',
    'RIVALON is a **real-money game platform**: you pay an entry fee and can win cash prizes. **India treats online games played for money like gambling and prohibits them** (Promotion and Regulation of Online Gaming Act, 2025).',
    '**If you are in India, please do not install, log in to or use this app.** If you use RIVALON from a place where such games are not allowed, you do so at your own risk and you are fully responsible for it.',
  ]),
  _H2('About RIVALON'),
  _P(
    'RIVALON is a platform where players join Free Fire tournaments hosted by us and receive prizes based on the results. Free Fire is a game owned by Garena. RIVALON is not run by or connected with Garena.',
  ),
  _H2('Who can use it'),
  _Ul([
    'You must be 18 years or older.',
    '**RIVALON is not meant for people in India.** Do not install or use it if you live in or are currently in India, or in any place where games played for money are not allowed.',
    'You are responsible for following the laws of the place where you live. By using RIVALON you confirm that using it is legal for you. We are not responsible for any problem that comes from using it where it is not allowed.',
    'One person can have one account. Duplicate or fake accounts are not allowed.',
  ]),
  _H2('Your account and Game ID'),
  _Ul([
    'You log in with an email and password or with Google. Keep your login details private.',
    'Before joining a match you must save your own Free Fire in-game name and UID in Profile. Prizes are given to the UID saved on your profile.',
    'One Free Fire UID can be linked to only one account. Do not change your Game ID while you have a match that is not finished.',
  ]),
  _H2('Tournaments'),
  _Ul([
    'The entry fee, prize pool, number of slots, map and start time are shown on the tournament page before you join.',
    'When you join you pick a slot number. Slots are first come, first served. **Play only in the slot you booked.** If you sit in another slot you can be kicked out and your fee is not refunded.',
    'The Room ID and password appear in My Matches once we add them, and we send a notification. Do not share them with anyone who has not joined.',
    'You can leave a match and get your entry fee back only before the match starts and before the Room ID is shared. After that, leaving is closed.',
    'Once a match is live, joining is closed.',
  ]),
  _H2('Loot (free) matches'),
  _Ul([
    'Loot matches have no entry fee. They can be joined only on Sunday (India time).',
    'Rewards from Loot matches are added to your Winnings after the results, and all other rules (Game ID, slots, fair play) apply the same way.',
  ]),
  _H2('Fair play'),
  _Ul([
    'Hacks, cheats, mods, scripts and any unfair tools are banned.',
    'Teaming up with other players or squads, ghosting, stream sniping and abusing game bugs are not allowed.',
    'Abusive or threatening behaviour towards other players or our team is not tolerated.',
    'Anyone who breaks these rules can be disqualified, lose their prize and have their account suspended.',
  ]),
  _H2('Wallet and payments'),
  _Ul([
    'You can add ₹5 to ₹100 in one payment. Depending on what we have turned on, you either pay by UPI (scan the QR code and send us your UTR / transaction ID) or pay through an online payment gateway.',
    '**UPI QR payments:** our team checks the payment against our bank statement and then adds the money to your wallet, usually within 4 hours. Until then it shows as Pending. Pay exactly the amount you entered and send the correct UTR.',
    '**Gateway payments:** your wallet is updated after the gateway confirms the payment.',
    'Fake, wrong or repeated payment requests are treated as fraud. We can reject them, send a warning, and put your account on hold.',
    'Your wallet has a Deposited balance (money you added), a Winnings balance (prizes you won) and a Bonus balance. Entry fees are taken from Deposited first, then Bonus, then Winnings.',
    'Only your Winnings balance can be withdrawn. Money you added cannot be withdrawn. You can move Winnings into Deposited to join matches, but once moved it can no longer be withdrawn.',
    'Withdrawals go to the UPI ID saved in your Profile. The minimum is ₹20 per request and the daily limit is ₹100. One withdrawal request can be pending at a time.',
    'Withdrawals are reviewed and paid by our team, normally within 24 hours. A request shows as Pending until it is paid or rejected. A rejected request is returned to your Winnings balance.',
  ]),
  _H2('Results and prizes'),
  _Ul([
    'Results are declared after the match ends, based on the in-game result. Position prizes and per-kill rewards are added to your Winnings.',
    '**Rewards can take up to 24 hours** to reach your wallet while we verify the results.',
    'If you think a result is wrong, contact us with a screenshot. Our decision after review is final.',
  ]),
  _H2('Account hold, suspension and closing'),
  _P(
    'We may warn, hold, suspend or close accounts for rule violations, fake payments or misuse of the app. While an account is on hold you cannot join matches, add money or withdraw, and you will see an "account on hold" message. Contact us to sort it out.',
  ),
  _H2('Notifications'),
  _P(
    'If you allow push notifications we send match, room, payment and prize alerts to your device. You can turn them off in Profile.',
  ),
  _H2('Responsible play'),
  _P(
    'Play for fun and skill, and only spend what you can afford. You can lose the entry fee you pay. If gaming starts to affect your studies, work, money or mood, take a break and stop joining paid matches.',
  ),
  _H2('Limits of our responsibility'),
  _P(
    'We do not guarantee that you will win anything. We are not responsible for game servers, internet problems on your side, in-game issues, or any legal problem that comes from you using RIVALON where it is not allowed. We work to keep RIVALON available but cannot promise it will never be interrupted.',
  ),
  _H2('Changes and governing law'),
  _P(
    'We may update these terms from time to time and change the date above when we do. Using RIVALON after an update means you accept the updated terms. These terms are governed by the laws of India.',
  ),
  _H2('Contact'),
  _P('Questions about these terms: {email}.'),
];

const List<_Blk> _privacy = [
  _Upd('Last updated: 28 Oct 2026'),
  _H2('What this covers'),
  _P(
    'This policy explains what information RIVALON collects, why we collect it, and the choices you have. RIVALON is not meant for people in India (see Terms).',
  ),
  _H2('Information we collect'),
  _Ul([
    '**Account details:** your name, email address and profile picture from the login method you use (email or Google).',
    '**Game details:** your Free Fire in-game name and UID, the matches you join, your booked slot and your results.',
    '**Payment details:** the amount and the UTR / transaction ID you send when you add money, or the order status from the payment gateway.',
    '**Withdrawal details:** your UPI ID and, if you add one, a screenshot of your UPI app.',
    '**Wallet records:** your payments, entry fees, winnings, moves between balances and withdrawals.',
    '**Notification token:** an identifier for your device, only if you allow push notifications.',
    '**Account actions:** a record if your account is put on hold, and the reason, for our own records.',
    '**Technical data:** basic logs such as your IP address and browser type, used to keep the service secure.',
  ]),
  _H2('Payments'),
  _P(
    'You pay through your own UPI app or the payment gateway page. We never receive or store your card number, PIN or UPI PIN. We only keep the amount and the transaction details needed to verify your payment.',
  ),
  _H2('How we use your information'),
  _Ul([
    'To create your account, let you join matches and give you the correct prizes.',
    'To add money, record transactions and pay your withdrawals.',
    'To send match, room, payment and prize alerts you have allowed.',
    'To prevent fraud, fake payments, duplicate accounts and cheating, and to resolve disputes.',
    'To answer your support requests.',
  ]),
  _H2('Who we share it with'),
  _P(
    'We do not sell your personal information. We share it only with services needed to run RIVALON: Google Firebase (login and notifications), our payment gateway (TranzUPI) when you pay through it, and our hosting provider. We may also share information when the law requires it, or to protect our users and platform from fraud.',
  ),
  _H2('Cookies'),
  _P(
    'We use a session cookie to keep you logged in. We do not use it for advertising.',
  ),
  _H2('How long we keep it'),
  _P(
    'We keep your account and wallet records while your account is active, and for as long as needed afterwards for accounting, security and legal reasons. Some old notification and payment-request logs may be deleted from time to time.',
  ),
  _H2('Security'),
  _P(
    'Your UPI screenshots are stored privately and are visible only to our admin team. We take reasonable steps to protect your information, but no online service can be completely secure.',
  ),
  _H2('Your choices'),
  _Ul([
    'You can turn push notifications on or off in Profile.',
    'You can update your Game ID and UPI ID in Profile.',
    'You can ask us to correct or delete your account information by emailing {email}. We may need to keep some records where the law requires it.',
  ]),
  _H2('Age'),
  _P(
    'RIVALON is for people aged 18 and over. We do not knowingly collect information from anyone under 18.',
  ),
  _H2('Changes and contact'),
  _P(
    'We may update this policy and will change the date above when we do. For privacy questions, email {email}.',
  ),
];

const List<_Blk> _refund = [
  _Upd('Last updated: 28 Oct 2026'),
  _H2('Tournament entry fees'),
  _Ul([
    '**You leave before the match starts (and before the Room ID is shared):** your entry fee is returned to your wallet straight away.',
    '**We cancel or delete a tournament before it ends:** the entry fee is returned to your wallet.',
    '**We reschedule a tournament:** your entry stays valid for the new time.',
    '**You miss the match, join late, play in the wrong slot or are disqualified:** the entry fee is not refunded.',
    'Once the Room ID is shared or the match is live, you cannot leave it.',
    'Loot matches are free, so there is nothing to refund.',
    'To join Loot matches you must play at least 1 paid tournament every week. This resets every Monday at 12:00 AM (India time).',
  ]),
  _H2('Adding money to your wallet'),
  _Ul([
    'Money is added to your Deposited balance after your payment is verified. UPI QR payments are checked by our team against our bank statement, usually within 4 hours. Gateway payments are added after the gateway confirms them. This balance is for entry fees and cannot be withdrawn.',
    '**If a payment fails:** your wallet balance does not change. If your bank or UPI app still shows the money as deducted, it is normally returned to you by your bank within 5 to 7 working days.',
    '**If money was deducted and the payment is not added to your wallet:** email us with your payment ID or UPI transaction ID (UTR). We will check it and add the money or arrange a refund.',
    '**If your payment request is rejected** because we did not receive the money, nothing is added. Fake or wrong requests are treated as fraud and can lead to a warning and an account hold.',
    '**If you added money by mistake:** contact us before using it. We review each request, and if it is approved the refund goes back to the original payment method within 5 to 7 working days.',
  ]),
  _H2('Withdrawals'),
  _Ul([
    'Withdrawals are reviewed and paid by our team to the UPI ID saved in your Profile, normally within 24 hours.',
    'If we reject a withdrawal request, the full amount is returned to your Winnings balance.',
    'Make sure your UPI ID is correct. We cannot recover money sent to a UPI ID that you entered wrongly.',
    'Money you moved from Winnings to Deposited can no longer be withdrawn.',
  ]),
  _H2('Prizes'),
  _P(
    'Prizes and kill rewards are added to your Winnings balance after results are declared. **This can take up to 24 hours.** If you believe a prize was calculated wrongly, contact us with a screenshot and we will review it.',
  ),
  _H2('How to ask for a refund'),
  _P(
    'Email {email} with the email you log in with, your Free Fire name and UID, the tournament name and time (if it is about a match), and the payment ID or a screenshot (if it is about a payment).',
  ),
];

const List<_Blk> _contact = [
  _Upd('We usually reply within 1 to 2 working days.'),
  _Cbox(),
  _H2('Business details'),
  _P('**RIVALON**'),
  _H2('When you contact us, please send'),
  _Ul([
    'The email you log in with.',
    'Your Free Fire name and UID.',
    'The tournament name and time, if it is about a match.',
    'A screenshot, the payment ID or the UPI transaction ID, if it is about a payment or withdrawal.',
  ]),
];

const List<List<_Blk>> _pages = [_terms, _privacy, _refund, _contact];

// ============================================================
//  Page
// ============================================================
enum _Phase { idle, out, inn }

class LegalPage extends StatefulWidget {
  const LegalPage({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> with TickerProviderStateMixin {
  static const Cubic _outCurve = Cubic(.4, 0, .2, 1);

  final _scroll = ScrollController();
  late final AnimationController _out = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final AnimationController _spark = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final TapGestureRecognizer _mailTap = TapGestureRecognizer()
    ..onTap = _openMail;

  late int _idx; // content jo dikh raha hai
  late int _sel; // selected tab (thumb)
  int _dir = 0; // 1 = aage, -1 = peeche, 0 = up
  _Phase _phase = _Phase.inn;
  bool _leaving = false;
  bool _started = false;

  bool get _reduce => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _idx = _sel = widget.initialIndex.clamp(0, 3).toInt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = MediaQuery.of(context).disableAnimations;
    if (r) {
      _flow.stop();
    } else if (!_flow.isAnimating) {
      _flow.repeat(reverse: true);
    }
    if (!_started) {
      _started = true;
      if (r) {
        _enter.value = 1;
        _spark.value = 1;
        _phase = _Phase.idle;
      } else {
        _spark.forward(from: 0);
        _enter.forward(from: 0).whenComplete(() {
          if (mounted && _phase == _Phase.inn && !_leaving) {
            setState(() => _phase = _Phase.idle);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _out.dispose();
    _enter.dispose();
    _spark.dispose();
    _flow.dispose();
    _mailTap.dispose();
    super.dispose();
  }

  // ---------- actions ----------
  Future<void> _launch(
    Uri u, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async {
    try {
      await launchUrl(u, mode: mode);
    } catch (_) {}
  }

  void _openMail() => _launch(Uri(scheme: 'mailto', path: _email));
  void _openGmail() =>
      _launch(Uri.parse(_gmailUrl), mode: LaunchMode.externalApplication);

  Future<void> _switchTo(int i) async {
    if (i == _sel) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
    if (_leaving) return;

    if (_reduce) {
      setState(() {
        _sel = i;
        _idx = i;
        _phase = _Phase.idle;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
      return;
    }

    _leaving = true;
    setState(() {
      _dir = i > _sel ? 1 : -1;
      _sel = i;
      _phase = _Phase.out;
    });
    _spark.forward(from: 0);
    await _out.forward(from: 0);
    if (!mounted) return;
    _enter.value = 0;
    setState(() {
      _idx = i;
      _phase = _Phase.inn;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _enter.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _leaving = false;
    });
  }

  Future<void> _back() async {
    if (_leaving) return;
    _leaving = true;
    final nav = Navigator.of(context);
    if (!_reduce) {
      setState(() {
        _dir = 0;
        _phase = _Phase.out;
      });
      await _out.forward(from: 0);
      if (!mounted) return;
    }
    final popped = await nav.maybePop();
    if (popped || !mounted) return;
    nav.pushReplacementNamed('/login');
  }

  // ============================================================
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final vh = mq.size.height;
    final h1 = (mq.size.width * .056).clamp(20.0, 24.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        controller: _scroll,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 620,
              child: IgnorePointer(child: CustomPaint(painter: _GlowPainter())),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, minHeight: vh),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    18 + mq.padding.top,
                    16,
                    36 + mq.padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(h1),
                      _seg(),
                      const SizedBox(height: 16),
                      _animatedView(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_docCard(_pages[_idx]), _footer()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- header ----------
  Widget _header(double h1) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Pressable(
            scale: .92,
            duration: const Duration(milliseconds: 250),
            onTap: _back,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c(255, 255, 255, .13), c(255, 255, 255, .04)],
                ),
                border: Border.all(color: c(255, 255, 255, .18)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _InsetHi(21, c(255, 255, 255, .15)),
                    ),
                  ),
                  svgIcon('<path d="M19 12H5M11 6l-6 6 6 6"/>', '#f1f5f3', 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titles[_idx],
                  style: t(
                    h1,
                    FontWeight.w700,
                    c(241, 245, 243),
                    ls: .02 * h1,
                    h: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'RIVALON',
                  style: t(11, FontWeight.w400, c(159, 217, 199), ls: 2.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- tabs switch ----------
  Widget _seg() {
    final reduce = _reduce;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c(255, 255, 255, .13), c(255, 255, 255, .04)],
        ),
        border: Border.all(color: c(255, 255, 255, .18)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _InsetHi(21, c(255, 255, 255, .15))),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              height: 44,
              child: LayoutBuilder(
                builder: (context, box) {
                  final tw = (box.maxWidth - 18) / 4;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
                        curve: kEase,
                        left: _sel * (tw + 6),
                        top: 0,
                        bottom: 0,
                        width: tw,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  c(76, 201, 170, .3),
                                  c(76, 201, 170, .12),
                                ],
                              ),
                              border: Border.all(color: c(110, 230, 195, .4)),
                              boxShadow: [
                                BoxShadow(
                                  color: c(54, 184, 152, .25),
                                  blurRadius: 18,
                                ),
                              ],
                            ),
                            child: CustomPaint(
                              painter: _InsetHi(15, c(255, 255, 255, .2)),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            SizedBox(width: tw, child: _tab(i)),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(int i) {
    final on = i == _sel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchTo(i),
      child: SizedBox(
        height: 44,
        child: AnimatedScale(
          scale: on ? 1.06 : 1,
          duration: _reduce ? Duration.zero : const Duration(milliseconds: 350),
          curve: kEase,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_pulseGlowOutside && on) Positioned.fill(child: _pulseGlow()),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (on) Positioned.fill(child: _fx()),
                      AnimatedDefaultTextStyle(
                        duration: _reduce
                            ? Duration.zero
                            : const Duration(milliseconds: 350),
                        curve: kEase,
                        style: on
                            ? t(14, FontWeight.w600, Colors.white).copyWith(
                                shadows: [
                                  Shadow(
                                    color: c(110, 230, 195, .45),
                                    blurRadius: 12,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              )
                            : t(12.5, FontWeight.w500, c(174, 187, 182)),
                        child: Text(
                          _tabLabels[i],
                          maxLines: 1,
                          softWrap: false,
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
    );
  }

  double _ringOpacity(double v) => v < .25
      ? Curves.easeOut.transform(v / .25)
      : 1 - Curves.easeOut.transform((v - .25) / .75);

  /// pulse ring + shine sweep (1.3s)
  Widget _fx() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _spark,
        builder: (_, _) {
          final v = _spark.value;
          if (v <= 0 || v >= 1) return const SizedBox.shrink();
          final s = Curves.easeOut.transform(v);
          final ringA = .7 + (.15 - .7) * s;
          final so = v < .2
              ? kEase.transform(v / .2)
              : (v < .75
                    ? 1 - .3 * kEase.transform((v - .2) / .55)
                    : .7 * (1 - kEase.transform((v - .75) / .25)));
          final x = -1.3 + 2.6 * kEase.transform(v);
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: _ringOpacity(v).clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c(165, 255, 228, ringA)),
                  ),
                ),
              ),
              Opacity(
                opacity: so.clamp(0.0, 1.0),
                child: LayoutBuilder(
                  builder: (_, b) {
                    final g = _cssGrad(
                      110,
                      Size(b.maxWidth, b.maxHeight),
                      [
                        c(220, 255, 244, 0),
                        c(220, 255, 244, .58),
                        c(110, 230, 195, .32),
                        c(220, 255, 244, 0),
                      ],
                      const [.25, .48, .54, .76],
                    );
                    return FractionalTranslation(
                      translation: Offset(x, 0),
                      child: Transform(
                        transform: Matrix4.skewX(-18 * pi / 180),
                        alignment: Alignment.center,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: g),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pulseGlow() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _spark,
        builder: (_, _) {
          final v = _spark.value;
          if (v <= 0 || v >= 1) return const SizedBox.shrink();
          final s = Curves.easeOut.transform(v);
          return Opacity(
            opacity: _ringOpacity(v).clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: c(76, 201, 170, .45 * (1 - s)),
                    blurRadius: 16 * s,
                    spreadRadius: 5 * s,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------- content slide ----------
  Widget _animatedView(Widget child) {
    return AnimatedBuilder(
      animation: Listenable.merge([_out, _enter]),
      child: child,
      builder: (_, ch) {
        double o = 1, dx = 0, dy = 0;
        if (_phase == _Phase.out) {
          final e = _outCurve.transform(_out.value);
          o = 1 - e;
          if (_dir == 0) {
            dy = 14 * e;
          } else {
            dx = -46.0 * _dir * e;
          }
        } else if (_phase == _Phase.inn) {
          final e = kEase.transform(_enter.value);
          o = e;
          if (_dir == 0) {
            dy = 22 * (1 - e);
          } else {
            dx = 46.0 * _dir * (1 - e);
          }
        }
        if (o >= 1 && dx == 0 && dy == 0) return ch!;
        return Opacity(
          opacity: o.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(dx, dy), child: ch),
        );
      },
    );
  }

  // ---------- document card ----------
  TextStyle get _pStyle => t(13, FontWeight.w400, c(201, 214, 209), h: 1.7);

  List<InlineSpan> _spans(String s, TextStyle base) {
    final bold = base.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    );
    final link = base.copyWith(
      color: c(110, 230, 195),
      decoration: TextDecoration.underline,
      decorationColor: c(110, 230, 195),
    );
    final out = <InlineSpan>[];
    var isBold = false;
    var pos = 0;
    for (final m in RegExp(r'\*\*|\{email\}').allMatches(s)) {
      if (m.start > pos) {
        out.add(
          TextSpan(
            text: s.substring(pos, m.start),
            style: isBold ? bold : null,
          ),
        );
      }
      if (m.group(0) == '**') {
        isBold = !isBold;
      } else {
        out.add(TextSpan(text: _email, style: link, recognizer: _mailTap));
      }
      pos = m.end;
    }
    if (pos < s.length) {
      out.add(TextSpan(text: s.substring(pos), style: isBold ? bold : null));
    }
    return out;
  }

  Widget _rich(String s, TextStyle base) =>
      Text.rich(TextSpan(style: base, children: _spans(s, base)));

  Widget _docCard(List<_Blk> blocks) {
    final kids = <Widget>[];
    double prev = 0;
    var h2Seen = false;
    for (final b in blocks) {
      double top = 0, bottom = 8;
      Widget w;
      if (b is _Upd) {
        bottom = 16;
        w = Align(alignment: Alignment.centerLeft, child: _pill(b.text));
      } else if (b is _Notice) {
        bottom = 18;
        w = _notice(b);
      } else if (b is _H2) {
        top = h2Seen ? 22 : 0;
        h2Seen = true;
        w = _h2(b.text);
      } else if (b is _P) {
        w = _rich(b.text, _pStyle);
      } else if (b is _Ul) {
        w = _ul(b.items);
      } else {
        bottom = 12;
        w = _ContactBox(flow: _flow, onTap: _openGmail);
      }
      final gap = max(prev, top);
      if (kids.isNotEmpty && gap > 0) kids.add(SizedBox(height: gap));
      kids.add(w);
      prev = bottom;
    }
    kids.add(SizedBox(height: prev));

    final base = c(10, 10, 10);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(c(255, 255, 255, .06), base),
            Color.alphaBlend(c(255, 255, 255, .015), base),
          ],
        ),
        border: Border.all(color: c(255, 255, 255, .1)),
        boxShadow: [BoxShadow(color: c(44, 150, 124, .1), blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kids,
      ),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: c(76, 201, 170, .1),
      border: Border.all(color: c(76, 201, 170, .3)),
    ),
    child: Text(text, style: t(11, FontWeight.w400, c(159, 217, 199))),
  );

  Widget _h2(String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 3,
        height: 15,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4CC9AA), Color(0xFF1B6F5C)],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: t(15, FontWeight.w600, c(230, 255, 246))),
      ),
    ],
  );

  Widget _ul(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        _li(items[i]),
      ],
    ],
  );

  Widget _li(String s) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 18),
        child: _rich(s, _pStyle),
      ),
      Positioned(
        left: 3,
        top: 9,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c(76, 201, 170),
            boxShadow: [BoxShadow(color: c(76, 201, 170, .7), blurRadius: 8)],
          ),
        ),
      ),
    ],
  );

  Widget _notice(_Notice n) {
    final base = t(13, FontWeight.w400, c(243, 232, 200), h: 1.7);
    final stop = t(13, FontWeight.w400, c(252, 165, 165), h: 1.7);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: c(20, 12, 4, .6),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c(251, 191, 36, .16), c(239, 68, 68, .08)],
        ),
        border: Border.all(color: c(251, 191, 36, .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(n.title, style: t(14, FontWeight.w600, c(253, 230, 138))),
          const SizedBox(height: 8),
          for (var i = 0; i < n.paras.length; i++) ...[
            _rich(n.paras[i], i == n.paras.length - 1 ? stop : base),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ---------- footer ----------
  Widget _footer() {
    final base = t(11.5, FontWeight.w400, c(141, 154, 149), h: 2);
    final link = base.copyWith(
      color: c(195, 205, 201),
      decoration: TextDecoration.underline,
      decorationColor: c(195, 205, 201),
    );
    InlineSpan l(int i) => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchTo(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(_tabLabels[i], style: link),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            l(0),
            const TextSpan(text: ' • '),
            l(1),
            const TextSpan(text: ' • '),
            l(2),
            const TextSpan(text: ' • '),
            l(3),
            const TextSpan(text: '\n© RIVALON'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ============================================================
//  Contact box (.cbox) - login ke _InfoBlock jaisa flowing glow
// ============================================================
class _ContactBox extends StatelessWidget {
  const _ContactBox({required this.flow, required this.onTap});
  final Animation<double> flow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flow,
      builder: (_, _) {
        final p = Curves.easeInOut.transform(flow.value);
        final begin = -1 - 2.8 * p;
        return Pressable(
          scale: .985,
          onTap: onTap,
          child: Container(
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _InsetHi(25, c(255, 255, 255, .08)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: c(110, 230, 195, .4)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              c(76, 201, 170, .26),
                              c(76, 201, 170, .06),
                            ],
                          ),
                        ),
                        child: svgIcon(
                          '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
                          '#c4f7e6',
                          22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Email us',
                              style: t(12, FontWeight.w400, c(207, 232, 223)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _email,
                              style: t(15, FontWeight.w600, Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
