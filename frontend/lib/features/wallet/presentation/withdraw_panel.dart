// lib/features/wallet/presentation/withdraw_panel.dart
part of 'wallet_page.dart';

class WithdrawPanel extends StatefulWidget {
  const WithdrawPanel({
    super.key,
    required this.wallet,
    required this.notify,
    required this.onSubmit,
    this.onOpenProfile,
  });

  final WalletState wallet;
  final WalletNotify notify;

  /// Called with a valid amount; returns true when the request was accepted.
  final Future<bool> Function(int amount) onSubmit;
  final VoidCallback? onOpenProfile;

  @override
  State<WithdrawPanel> createState() => _WithdrawPanelState();
}

class _WithdrawPanelState extends State<WithdrawPanel> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _withdraw() async {
    final w = widget.wallet;
    final a = int.tryParse(_ctl.text) ?? 0;
    final minW = w.limits.minWithdraw;
    final limit = w.limits.dailyLimit;

    if (!w.hasUpi) {
      widget.notify(
        WalletToastType.warn,
        'Add your UPI ID first',
        'Save your UPI ID in Profile to withdraw your winnings.',
      );
      return;
    }
    if (a == 0) {
      widget.notify(
        WalletToastType.warn,
        'Enter an amount',
        'Minimum withdrawal is ₹${inr(minW)}.',
      );
      return;
    }
    if (a < minW) {
      widget.notify(
        WalletToastType.err,
        'Minimum withdrawal is ₹${inr(minW)}',
        'You can withdraw ₹${inr(minW)} or more at a time.',
      );
      return;
    }
    if (a > w.winnings) {
      widget.notify(
        WalletToastType.err,
        'Not enough winnings',
        w.winnings > 0
            ? 'Only winnings can be withdrawn. You have ₹${inr(w.winnings)} available.'
            : 'Only winnings can be withdrawn. Money you added cannot be withdrawn.',
      );
      return;
    }
    if (a > w.dailyLeft) {
      if (w.dailyLeft > 0) {
        widget.notify(
          WalletToastType.err,
          'Daily limit is ₹${inr(limit)}',
          'You can withdraw ₹${inr(w.dailyLeft)} more today.',
        );
      } else {
        widget.notify(
          WalletToastType.err,
          'Daily limit reached',
          'You have withdrawn ₹${inr(limit)} today. Try again tomorrow.',
        );
      }
      return;
    }

    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.onSubmit(a);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (ok && mounted) _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wallet;
    final warn = !w.hasUpi;
    final accent = warn ? _gold : _g2;
    final accentHex = warn ? '#fbbf24' : '#6ee6c3';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _H2('Withdraw'),
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
              _Capsule(
                controller: _ctl,
                focusNode: _focus,
                hint: 'Amount',
                maxLen: 6,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Surface(
                  r: 20,
                  color: rsC(255, 255, 255, .05),
                  border: warn
                      ? rsC(251, 191, 36, .5)
                      : rsC(255, 255, 255, .12),
                  hl: rsC(255, 255, 255, .08),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: <Widget>[
                      _icon(_icWallet, accentHex, 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              warn ? 'UPI ID needed' : 'Money will be sent to',
                              style: _t(10, FontWeight.w400, _muted, h: 1.5),
                            ),
                            Text(
                              warn ? 'Add your UPI ID to withdraw' : w.upi,
                              style: _t(14, FontWeight.w700, _white, h: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpenProfile,
                        child: Text(
                          warn ? 'Add' : 'Change',
                          style: _t(12, FontWeight.w600, accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Btn(
                  variant: _BV.ghost,
                  label: 'Withdraw',
                  onTap: _busy ? null : _withdraw,
                ),
              ),
              _Hint(
                'Withdrawable (winnings): ₹${inr(w.winnings)} • Minimum ₹${inr(w.limits.minWithdraw)} • Left today: ₹${inr(w.dailyLeft)} of ₹${inr(w.limits.dailyLimit)}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
