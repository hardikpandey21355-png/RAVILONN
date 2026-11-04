// lib/features/wallet/presentation/add_money_panel.dart
part of 'wallet_page.dart';

class AddMoneyPanel extends StatefulWidget {
  const AddMoneyPanel({
    super.key,
    required this.notify,
    required this.onSubmit,
    required this.minAdd,
    required this.maxAdd,
    this.paymentMethod = 'gateway',
  });

  final WalletNotify notify;
  final int minAdd;
  final int maxAdd;
  final String paymentMethod;

  /// Called with a valid amount. Completes when the payment flow is done
  /// (the button stays disabled until then).
  final Future<void> Function(int amount) onSubmit;

  @override
  State<AddMoneyPanel> createState() => AddMoneyPanelState();
}

class AddMoneyPanelState extends State<AddMoneyPanel> {
  static const List<int> _chips = <int>[1, 10, 50, 100];

  final TextEditingController _ctl = TextEditingController(text: '100');
  final FocusNode _focus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_onText);
  }

  @override
  void dispose() {
    _ctl.removeListener(_onText);
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted) setState(() {});
  }

  /// "Add Money" button of the empty transactions state.
  void focusAmount() => _focus.requestFocus();

  void _setAmount(int v) {
    final s = '$v';
    _ctl.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }

  Future<void> _add() async {
    if (widget.paymentMethod != 'gateway') return;
    final a = int.tryParse(_ctl.text) ?? 0;
    final range = '₹${inr(widget.minAdd)} to ₹${inr(widget.maxAdd)}';
    if (a == 0) {
      widget.notify(
        WalletToastType.warn,
        'Enter an amount',
        'You can add $range in one payment.',
      );
      return;
    }
    if (a < widget.minAdd) {
      widget.notify(
        WalletToastType.err,
        'Minimum amount is ₹${inr(widget.minAdd)}',
        'You can add $range in one payment.',
      );
      return;
    }
    if (a > widget.maxAdd) {
      widget.notify(
        WalletToastType.err,
        'Maximum amount is ₹${inr(widget.maxAdd)}',
        'You can add $range in one payment.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSubmit(a);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txt = _ctl.text;
    final label = txt.isEmpty
        ? 'Add Money'
        : 'Add ₹${inr(int.tryParse(txt) ?? 0)}';
    final enabled = widget.paymentMethod == 'gateway';
    final buttonLabel = switch (widget.paymentMethod) {
      'off' => 'do not add money now',
      'manual' => 'To be completed',
      _ => label,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _H2('Add Money'),
        _Surface(
          r: 28,
          border: rsC(255, 255, 255, .13),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.fromRGBO(255, 255, 255, .045),
              Color.fromRGBO(255, 255, 255, .015),
            ],
          ),
          hl: rsC(255, 255, 255, .14),
          shadows: const <_Sh>[_Sh(10, 30, Color.fromRGBO(0, 0, 0, .35))],
          clip: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (var i = 0; i < _chips.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _AmtChip(
                        label: '₹${_chips[i]}',
                        selected: txt == '${_chips[i]}',
                        onTap: () => _setAmount(_chips[i]),
                      ),
                    ),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Capsule(
                  controller: _ctl,
                  focusNode: _focus,
                  hint: 'Enter amount',
                  maxLen: 6,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Btn(
                  variant: widget.paymentMethod == 'off'
                      ? _BV.paused
                      : _BV.primary,
                  label: _busy ? 'Preparing secure payment...' : buttonLabel,
                  leading: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFEAFFF7),
                          ),
                        )
                      : null,
                  onTap: _busy || !enabled ? null : _add,
                ),
              ),
              _Hint(
                widget.paymentMethod == 'off'
                    ? 'Adding money is paused by the admin.'
                    : widget.paymentMethod == 'manual'
                    ? 'Manual payments are not available yet.'
                    : 'Your wallet is updated after the payment is confirmed.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Amount chip: unselected glass -> selected green glass (400ms).
class _AmtChip extends StatelessWidget {
  const _AmtChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      scale: .93,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1.0 : 0.0),
        duration: _ms(context, 400),
        curve: Curves.ease,
        builder: (context, t, _) {
          final deco = BoxDecoration(
            color: Color.lerp(rsC(255, 255, 255, .06), _gbtnBase, t),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color.lerp(rsC(110, 230, 195, 0), rsC(110, 230, 195, .26), t)!,
                Color.lerp(rsC(27, 111, 92, 0), rsC(27, 111, 92, .2), t)!,
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Color.lerp(
                rsC(255, 255, 255, .14),
                rsC(140, 240, 210, .38),
                t,
              )!,
              width: 1,
            ),
          );
          return CustomPaint(
            painter: _ShadowPainter(999, <_Sh>[
              _Sh(6, 18, rsC(0, 0, 0, .35 * t)),
            ]),
            child: Container(
              height: 48,
              decoration: deco,
              child: Stack(
                fit: StackFit.passthrough,
                children: <Widget>[
                  Center(
                    child: Text(
                      label,
                      style: _t(
                        14,
                        FontWeight.w600,
                        Color.lerp(
                          rsC(0xC3, 0xD0, 0xCB),
                          const Color(0xFFEAFFF7),
                          t,
                        )!,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _HLPainter(
                          23,
                          Color.lerp(
                            rsC(255, 255, 255, .1),
                            rsC(255, 255, 255, .26),
                            t,
                          )!,
                        ),
                      ),
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
