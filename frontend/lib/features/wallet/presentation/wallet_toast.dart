// lib/features/wallet/presentation/wallet_toast.dart
part of 'wallet_page.dart';

enum WalletToastType { err, warn, ok }

typedef WalletNotify =
    void Function(WalletToastType type, String title, String text);

/// Top pop notification. Put it once in a Stack and call
/// `key.currentState?.show(type, title, text)`.
class WalletToast extends StatefulWidget {
  const WalletToast({super.key});

  @override
  State<WalletToast> createState() => WalletToastState();
}

class WalletToastState extends State<WalletToast>
    with TickerProviderStateMixin {
  static const String _icErr =
      '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5M12 16h.01"/>';
  static const String _icWarn =
      '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17h.01"/>';
  static const String _icOk =
      '<circle cx="12" cy="12" r="9"/><path d="M8 12.5l3 3 5-6"/>';

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  Timer? _timer;
  Timer? _busy;
  bool _shown = false;
  WalletToastType _type = WalletToastType.ok;
  String _title = '';
  String _text = '';

  @override
  void dispose() {
    _timer?.cancel();
    _busy?.cancel();
    _slide.dispose();
    _bar.dispose();
    super.dispose();
  }

  void hide() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _shown = false);
    _slide.reverse();
  }

  void show(WalletToastType type, String title, String text) {
    _timer?.cancel();
    _busy?.cancel();

    void go() {
      if (!mounted) return;
      final off = MediaQuery.of(context).disableAnimations;
      _slide.duration = off ? Duration.zero : const Duration(milliseconds: 500);
      _slide.reverseDuration = _slide.duration;
      setState(() {
        _type = type;
        _title = title;
        _text = text;
        _shown = true;
      });
      if (!off) _bar.forward(from: 0);
      _slide.forward();
      _timer = Timer(const Duration(seconds: 3), hide);
    }

    if (_shown) {
      hide();
      _busy = Timer(const Duration(milliseconds: 220), go);
    } else {
      go();
    }
  }

  Color get _color {
    switch (_type) {
      case WalletToastType.err:
        return _redT;
      case WalletToastType.warn:
        return _gold;
      case WalletToastType.ok:
        return _greenT;
    }
  }

  String get _hex {
    switch (_type) {
      case WalletToastType.err:
        return '#f87171';
      case WalletToastType.warn:
        return '#fbbf24';
      case WalletToastType.ok:
        return '#4ade80';
    }
  }

  String get _iconPath {
    switch (_type) {
      case WalletToastType.err:
        return _icErr;
      case WalletToastType.warn:
        return _icWarn;
      case WalletToastType.ok:
        return _icOk;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 14;
    final color = _color;

    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[_slide, _bar]),
            builder: (context, _) {
              final v = _slide.value;
              if (v == 0 && !_shown) return const SizedBox.shrink();
              final move = kRsEase.transform(v);
              return IgnorePointer(
                ignoring: !_shown,
                child: Transform.translate(
                  offset: Offset(0, -24 * (1 - move)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: hide,
                    child: Material(
                      type: MaterialType.transparency,
                      child: _Surface(
                        surfaceKey: const ValueKey<String>(
                          'wallet-toast-surface',
                        ),
                        r: 22,
                        color: const Color(0xFF0D1512),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0xFF202A26), Color(0xFF101714)],
                        ),
                        border: rsC(255, 255, 255, .2),
                        hl: rsC(255, 255, 255, .1),
                        shadows: const <_Sh>[
                          _Sh(14, 36, Color.fromRGBO(0, 0, 0, .55)),
                        ],
                        clip: true,
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: rsC(255, 255, 255, .07),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: color,
                                        width: 1,
                                      ),
                                    ),
                                    child: _icon(_iconPath, _hex, 21),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _title,
                                          style: _t(
                                            13,
                                            FontWeight.w600,
                                            _white,
                                            h: 1.3,
                                          ),
                                        ),
                                        if (_text.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 1,
                                            ),
                                            child: Text(
                                              _text,
                                              style: _t(
                                                11.5,
                                                FontWeight.w400,
                                                const Color(0xFFC4D3CE),
                                                h: 1.45,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 3,
                              child: Transform(
                                alignment: Alignment.centerLeft,
                                transform: Matrix4.diagonal3Values(
                                  _shown ? 1 - _bar.value : 0,
                                  1,
                                  1,
                                ),
                                child: ColoredBox(color: color),
                              ),
                            ),
                          ],
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
    );
  }
}
