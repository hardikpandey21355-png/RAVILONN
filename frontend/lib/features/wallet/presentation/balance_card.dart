// lib/features/wallet/presentation/balance_card.dart
part of 'wallet_page.dart';

const String _kWalletTextImg = 'assets/images/wallet_text.jpg';

class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.total,
    required this.deposited,
    required this.winnings,
  });

  final int total;
  final int deposited;
  final int winnings;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;

  @override
  void initState() {
    super.initState();
    // The picture has to blend with the card (mix-blend-mode: screen), which
    // Image.asset cannot do, so it is decoded here and drawn by a painter.
    final stream = const AssetImage(
      _kWalletTextImg,
    ).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final old = _info;
        _info = info.clone();
        old?.dispose();
        if (mounted) setState(() {});
      },
      onError: (Object e, StackTrace? s) {
        debugPrint('BalanceCard: could not load $_kWalletTextImg ($e)');
      },
    );
    stream.addListener(_listener!);
    _stream = stream;
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Surface(
      r: 28,
      color: _glassBase,
      gradient: _glassGrad,
      border: rsC(255, 255, 255, .16),
      hl: rsC(255, 255, 255, .2),
      shadows: const <_Sh>[_Sh(14, 34, Color.fromRGBO(0, 0, 0, .45))],
      clip: true,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SnakePainter(_info?.image)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Total Balance',
                  style: _t(
                    12,
                    FontWeight.w400,
                    const Color(0xFFB9CBC5),
                    h: 1.5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 14),
                  child: Text(
                    '₹ ${inr(widget.total)}',
                    maxLines: 1,
                    softWrap: false,
                    style: _t(
                      _vw(context, 30, 9, 38),
                      FontWeight.w700,
                      _white,
                      h: 1.2,
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SplitBox(
                        label: 'Deposited',
                        value: '₹${inr(widget.deposited)}',
                        color: _g2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SplitBox(
                        label: 'Winnings',
                        value: '₹${inr(widget.winnings)}',
                        color: _greenT,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitBox extends StatelessWidget {
  const _SplitBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      r: 16,
      color: rsC(255, 255, 255, .05),
      border: rsC(255, 255, 255, .1),
      hl: rsC(255, 255, 255, .08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _line(24, Text(label, style: _t(10, FontWeight.w400, _muted))),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: _t(14, FontWeight.w600, color, h: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Draws the snake picture exactly like the CSS:
/// right:-8 top:-6 width:150, rotate(8deg) from the top-right corner,
/// filter brightness(1.25) saturate(1.1), radial mask, opacity .6,
/// mix-blend-mode: screen.
class _SnakePainter extends CustomPainter {
  const _SnakePainter(this.image);
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;

    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    const w = 150.0;
    final h = w * ih / iw;
    final rect = Rect.fromLTWH(size.width + 8 - w, -6, w, h);

    // brightness(1.25) then saturate(1.1)
    const s = 1.1, b = 1.25;
    final matrix = <double>[
      b * (.213 + .787 * s),
      b * (.715 - .715 * s),
      b * (.072 - .072 * s),
      0,
      0,
      b * (.213 - .213 * s),
      b * (.715 + .285 * s),
      b * (.072 - .072 * s),
      0,
      0,
      b * (.213 - .213 * s),
      b * (.715 - .715 * s),
      b * (.072 + .928 * s),
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    final origin = rect.topRight;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(8 * math.pi / 180);
    canvas.translate(-origin.dx, -origin.dy);

    // whole picture = one group: opacity .6 + screen blend with the card
    canvas.saveLayer(
      rect.inflate(2),
      Paint()
        ..blendMode = BlendMode.screen
        ..color = const Color.fromRGBO(255, 255, 255, .6),
    );
    // mask group
    canvas.saveLayer(rect.inflate(2), Paint());
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, iw, ih),
      rect,
      Paint()
        ..colorFilter = ColorFilter.matrix(matrix)
        ..filterQuality = FilterQuality.medium,
    );

    // radial-gradient(ellipse at 60% 45%, #000 35%, transparent 72%)
    final cx = rect.left + rect.width * .6;
    final cy = rect.top + rect.height * .45;
    final rx = math.sqrt2 * math.max(rect.width * .6, rect.width * .4);
    final ry = math.sqrt2 * math.max(rect.height * .45, rect.height * .55);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(rx, ry);
    final maskPaint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        const <Color>[Color(0xFF000000), Color(0x00000000)],
        const <double>[.35, .72],
      );
    canvas.drawRect(
      Rect.fromLTRB(
        (rect.left - 2 - cx) / rx,
        (rect.top - 2 - cy) / ry,
        (rect.right + 2 - cx) / rx,
        (rect.bottom + 2 - cy) / ry,
      ),
      maskPaint,
    );
    canvas.restore();

    canvas.restore(); // mask group
    canvas.restore(); // blend group
    canvas.restore(); // transform
  }

  @override
  bool shouldRepaint(_SnakePainter old) => old.image != image;
}
