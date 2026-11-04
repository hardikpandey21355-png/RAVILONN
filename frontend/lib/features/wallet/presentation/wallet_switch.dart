// lib/features/wallet/presentation/wallet_switch.dart
part of 'wallet_page.dart';

/// Left/width animated separately (left 400ms, width 300ms) like the CSS thumb.
Widget _slidingPositioned({
  required BuildContext context,
  required double left,
  required double width,
  double? top,
  double? bottom,
  double? height,
  required Widget child,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween<double>(end: left),
    duration: _ms(context, 400),
    curve: kRsEase,
    builder: (context, l, _) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(end: width),
        duration: _ms(context, 300),
        curve: kRsEase,
        builder: (context, w, _) {
          return Positioned(
            left: l,
            width: w,
            top: top,
            bottom: bottom,
            height: height,
            child: child,
          );
        },
      );
    },
  );
}

/// The green glass pill that slides behind the selected tab.
Widget _thumbBox(double radius) {
  return IgnorePointer(
    child: _Surface(
      r: radius,
      color: _gbtnBase,
      gradient: _gbtnGrad,
      border: _gbtnBorder,
      hl: rsC(255, 255, 255, .26),
      shadows: const <_Sh>[_Sh(6, 18, Color.fromRGBO(0, 0, 0, .35))],
      child: const SizedBox.expand(),
    ),
  );
}

class WalletSwitch extends StatelessWidget {
  const WalletSwitch({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  /// 0 = Add Money, 1 = Withdraw, 2 = Transactions
  final int selected;
  final ValueChanged<int> onSelect;

  static const List<String> _labels = <String>[
    'Add Money',
    'Withdraw',
    'Transactions',
  ];

  @override
  Widget build(BuildContext context) {
    const pad = 5.0;
    const gap = 5.0;
    const fixed = 10.0; // tab padding (4+4) + border (1+1)
    final fs = _vw(context, 10, 3.1, 13);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          // CSS: flex 1 1 0 (selected grows 1.45)
          final inner = c.maxWidth - 2; // minus border
          final free = inner - pad * 2 - gap * 2 - fixed * 3;
          final grows = <double>[
            for (var i = 0; i < 3; i++) i == selected ? 1.45 : 1.0,
          ];
          final growTotal = grows.fold<double>(0, (a, b) => a + b);
          final widths = <double>[
            for (var i = 0; i < 3; i++)
              math.max(fixed + free * grows[i] / growTotal, fixed),
          ];
          var thumbLeft = pad;
          for (var i = 0; i < selected; i++) {
            thumbLeft += widths[i] + gap;
          }

          return _Surface(
            r: 22,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color.fromRGBO(255, 255, 255, .13),
                Color.fromRGBO(255, 255, 255, .04),
              ],
            ),
            border: rsC(255, 255, 255, .18),
            hl: rsC(255, 255, 255, .15),
            child: SizedBox(
              height: pad * 2 + 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  _slidingPositioned(
                    context: context,
                    left: thumbLeft,
                    width: widths[selected],
                    top: pad,
                    bottom: pad,
                    child: _thumbBox(16),
                  ),
                  Positioned(
                    left: pad,
                    top: pad,
                    child: Row(
                      children: <Widget>[
                        for (var i = 0; i < 3; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: gap),
                          _SwitchTab(
                            label: _labels[i],
                            width: widths[i],
                            fontSize: fs,
                            on: i == selected,
                            onTap: () => onSelect(i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SwitchTab extends StatelessWidget {
  const _SwitchTab({
    required this.label,
    required this.width,
    required this.fontSize,
    required this.on,
    required this.onTap,
  });

  final String label;
  final double width;
  final double fontSize;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      scale: .97,
      dur: 0,
      onTap: onTap,
      child: AnimatedContainer(
        duration: _ms(context, 300),
        curve: kRsEase,
        width: width,
        height: 44,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: AnimatedDefaultTextStyle(
          duration: _ms(context, 300),
          style: _t(
            fontSize,
            FontWeight.w500,
            on ? const Color(0xFFEAFFF7) : const Color(0xFFAEBBB6),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}
