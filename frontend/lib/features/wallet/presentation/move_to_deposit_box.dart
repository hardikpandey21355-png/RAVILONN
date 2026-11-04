// lib/features/wallet/presentation/move_to_deposit_box.dart
part of 'wallet_page.dart';

const String _kWinToDepositImg = 'assets/images/win_to_deposite.jpg';

class MoveToDepositBox extends StatefulWidget {
  const MoveToDepositBox({
    super.key,
    required this.winnings,
    required this.notify,
    required this.onMove,
  });

  final int winnings;
  final WalletNotify notify;

  /// Called after the user confirmed. The page updates balance + list + tick.
  final Future<bool> Function(int amount) onMove;

  @override
  State<MoveToDepositBox> createState() => _MoveToDepositBoxState();
}

class _MoveToDepositBoxState extends State<MoveToDepositBox> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _all() {
    if (widget.winnings > 0) {
      final s = '${widget.winnings}';
      _ctl.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }

  Future<void> _move() async {
    final a = int.tryParse(_ctl.text) ?? 0;
    final w = widget.winnings;
    if (a == 0) {
      widget.notify(WalletToastType.warn, 'Enter an amount', 'Minimum is ₹1.');
      return;
    }
    if (a > w) {
      widget.notify(
        WalletToastType.err,
        'Not enough winnings',
        w > 0
            ? 'You have ₹${inr(w)} in winnings.'
            : 'You have no winnings to move yet.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: const Color.fromRGBO(0, 0, 0, .6),
      builder: (_) => _ConfirmDialog(
        message:
            'Move ₹${inr(a)} from winnings to deposit? It can no longer be withdrawn.',
      ),
    );
    if (ok != true || !mounted || _busy) return;
    setState(() => _busy = true);
    var moved = false;
    try {
      moved = await widget.onMove(a);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (moved && mounted) _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _Surface(
      r: 28,
      color: const Color(0xFF0D0E10),
      border: rsC(255, 255, 255, .22),
      hl: rsC(255, 255, 255, .18),
      shadows: const <_Sh>[_Sh(10, 30, Color.fromRGBO(0, 0, 0, .35))],
      clip: true,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          // background picture: bottom-centre cover, opacity .5, top fade mask
          Positioned.fill(
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xFF000000),
                      Color(0xFF000000),
                    ],
                    stops: <double>[0, .1, .7, 1],
                  ).createShader(bounds);
                },
                child: Opacity(
                  opacity: .5,
                  child: Image.asset(
                    _kWinToDepositImg,
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stack) {
                      debugPrint(
                        'MoveToDepositBox: could not load $_kWinToDepositImg ($error)',
                      );
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rsC(255, 255, 255, .1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: rsC(255, 255, 255, .3),
                            width: 1,
                          ),
                        ),
                        child: _icon(_icTrophy, '#ffffff', 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Move winnings to deposit',
                              style: _t(14, FontWeight.w700, _white, h: 1.25),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Winnings available: ₹${inr(widget.winnings)}',
                                style: _t(
                                  11,
                                  FontWeight.w400,
                                  const Color(0xFFB5B8BD),
                                  h: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _Capsule(
                  controller: _ctl,
                  focusNode: _focus,
                  hint: 'Amount',
                  maxLen: 7,
                  dark: true,
                  trailing: _Pressable(
                    scale: .92,
                    onTap: _all,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rsC(255, 255, 255, .12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: rsC(255, 255, 255, .35),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'All',
                        style: _t(12, FontWeight.w600, _white),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _Btn(
                    variant: _BV.violet,
                    label: 'Move to deposit',
                    onTap: _busy ? null : _move,
                  ),
                ),
                const _Hint(
                  'Minimum ₹1. Money moved to deposit can be used for entry fees but can no longer be withdrawn.',
                  color: Color(0xFFC9CCD1),
                  shadow: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark glass confirm dialog (replacement for the browser confirm()).
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: _Surface(
          r: 22,
          color: rsC(8, 16, 14, .92),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.fromRGBO(255, 255, 255, .12),
              Color.fromRGBO(255, 255, 255, .03),
            ],
          ),
          border: rsC(255, 255, 255, .16),
          hl: rsC(255, 255, 255, .18),
          shadows: const <_Sh>[_Sh(14, 36, Color.fromRGBO(0, 0, 0, .55))],
          blur: 4,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(message, style: _t(14, FontWeight.w500, _white, h: 1.5)),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Btn(
                      variant: _BV.ghost,
                      height: 44,
                      label: 'Cancel',
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Btn(
                      variant: _BV.primary,
                      height: 44,
                      label: 'Move',
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
