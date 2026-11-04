// lib/features/tournament_detail/presentation/join_sheet.dart
part of 'tournament_detail_page.dart';

enum SheetMode { add, game, join }

class JoinSheet extends StatefulWidget {
  const JoinSheet({
    super.key,
    required this.t,
    required this.balance,
    required this.loot,
    required this.toast,
    required this.onBalance,
    required this.onJoined,
    this.onLoadSlots,
    this.onJoin,
    this.onPay,
    this.onOpenProfile,
  });

  final TournamentDetail t;
  final int balance;
  final bool loot;
  final ValueChanged<String> toast;
  final ValueChanged<int> onBalance;
  final VoidCallback onJoined;
  final Future<SlotsResult> Function()? onLoadSlots;
  final Future<JoinResult> Function(int slot)? onJoin;
  final Future<PayResult> Function(int amount)? onPay;
  final VoidCallback? onOpenProfile;

  @override
  State<JoinSheet> createState() => JoinSheetState();
}

class JoinSheetState extends State<JoinSheet> {
  static const List<int> _chips = <int>[10, 20, 50, 100];

  SheetMode _mode = SheetMode.add;
  bool _visible = false; // mounted (visibility)
  bool _open = false; // faded in
  bool _busy = false;
  bool _done = false;

  String _title = '';
  String _sub = '';
  String _err = '';
  String _goLabel = '';
  bool _goDisabled = false;
  bool _goGreen = false;

  int _picked = 0;
  bool _loading = false;
  bool _failed = false;
  int _slotCount = 0;
  Set<int> _taken = <int>{};
  int _loadSeq = 0;

  final TextEditingController _amt = TextEditingController();
  final FocusNode _amtFocus = FocusNode();
  Timer? _hideTimer;
  Timer? _joinedTimer;

  bool get isOpen => _open;

  @override
  void initState() {
    super.initState();
    _amt.addListener(_rebuild);
    _amtFocus.addListener(_rebuild);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _joinedTimer?.cancel();
    _amt.removeListener(_rebuild);
    _amtFocus.removeListener(_rebuild);
    _amt.dispose();
    _amtFocus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ---- open / close ----
  void open(SheetMode m) {
    _hideTimer?.cancel();
    final t = widget.t;
    _mode = m;
    _err = '';
    _picked = 0;
    _done = false;
    _busy = false;
    _goDisabled = false;
    _goGreen = false;

    if (m == SheetMode.add) {
      final need = math.max(t.fee - widget.balance, 0);
      _title = 'Add money';
      _sub = need > 0
          ? 'You need ₹${_inr(need)} more to join ${t.modeTitle}.'
          : 'Add money to your wallet.';
      final s = '${math.min(math.max(need, 5), 100)}';
      _amt.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    } else if (m == SheetMode.game) {
      _title = 'Add your Game ID first';
      _sub =
          'Save your Free Fire name and UID in Profile before joining. Rewards go to the UID you save, so enter them exactly as they appear in the game.';
      _goLabel = 'Go to Profile';
    } else {
      _title = '';
      _sub = '';
      _goLabel = 'Select a slot';
      _goDisabled = true;
      _loadSlots();
    }

    setState(() => _visible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _visible) setState(() => _open = true);
    });
  }

  void close() {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _open = false);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  // ---- slots ----
  Future<void> _loadSlots() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _failed = false;
    });
    SlotsResult res;
    try {
      res = await (widget.onLoadSlots ?? () => TournamentDetailMock.loadSlots(widget.t))();
    } catch (e) {
      debugPrint('JoinSheet: loading slots failed ($e)');
      res = const SlotsResult(ok: false);
    }
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _loading = false;
      if (!res.ok) {
        _failed = true;
      } else {
        _failed = false;
        _slotCount = res.slots;
        _taken = res.taken.toSet();
      }
    });
  }

  void _pick(int n) {
    setState(() {
      _picked = n;
      _goDisabled = false;
      _goLabel = 'Confirm Slot $n • ₹${_inr(widget.t.fee)}';
      _err = '';
    });
  }

  // ---- main button ----
  Future<void> _go() async {
    if (_mode == SheetMode.game) {
      close();
      widget.onOpenProfile?.call();
      return;
    }

    if (_mode == SheetMode.join) {
      if (_done) return;
      if (_picked == 0) {
        setState(() => _err = 'Select a slot first.');
        return;
      }
      setState(() {
        _busy = true;
        _goDisabled = true;
        _err = '';
      });
      JoinResult res;
      try {
        final f = widget.onJoin;
        res = await (f != null
            ? f(_picked)
            : TournamentDetailMock.join(widget.t, widget.balance));
      } catch (e) {
        debugPrint('JoinSheet: join failed ($e)');
        res = const JoinResult(ok: false, error: 'Network problem. Try again.');
      }
      if (!mounted) return;
      if (!res.ok) {
        setState(() {
          _busy = false;
          _err = res.error ?? 'Could not join.';
          _picked = 0;
          _goDisabled = true;
          _goLabel = 'Select a slot';
        });
        _loadSlots();
        return;
      }
      if (res.newBalance != null) widget.onBalance(res.newBalance!);
      setState(() {
        _busy = false;
        _goDisabled = false;
        _done = true;
        _goGreen = true;
        _goLabel = 'Joined ✓';
      });
      _joinedTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        close();
        widget.onJoined();
      });
      return;
    }

    // add money
    final a = int.tryParse(_amt.text) ?? 0;
    if (a < 5 || a > 100) {
      setState(() => _err = 'Enter an amount between ₹5 and ₹100.');
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    PayResult res;
    try {
      final f = widget.onPay;
      res = await (f != null ? f(a) : TournamentDetailMock.pay(a));
    } catch (e) {
      debugPrint('JoinSheet: payment failed ($e)');
      res = const PayResult.failure('Something went wrong.');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      if (!res.cancelled) {
        setState(() => _err = res.error ?? 'Something went wrong.');
      }
      return;
    }
    close();
    widget.toast(
        'Payment sent for approval. You can join once your wallet is updated.');
  }

  // ---- build ----
  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final loot = widget.loot;

    String goLabel = _goLabel;
    bool goDisabled = _goDisabled || _busy;
    if (_mode == SheetMode.add) {
      goLabel = 'Pay ₹${_inr(int.tryParse(_amt.text) ?? 0)}';
      goDisabled = _busy;
    }

    final Widget panelBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_mode != SheetMode.join)
          Text(_title, style: _t(17, FontWeight.w600, _white, h: 1.5)),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
          child: _mode == SheetMode.join
              ? const _SlotWarn()
              : Text(_sub, style: _t(12, FontWeight.w400, _muted, h: 1.4)),
        ),
        if (_mode == SheetMode.add) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < _chips.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _chip(_chips[i])),
                ],
              ],
            ),
          ),
          _field(),
        ],
        if (_mode == SheetMode.join) ...<Widget>[
          _legend(loot),
          SlotGrid(
            loading: _loading,
            failed: _failed,
            slots: _slotCount,
            taken: _taken,
            picked: _picked,
            loot: loot,
            onPick: _pick,
          ),
        ],
        Container(
          constraints: const BoxConstraints(minHeight: 18),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Text(_err,
              style: _t(12, FontWeight.w400, const Color(0xFFF87171), h: 1.5)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _Btn(
            variant: _goGreen ? _BV.green : _BV.primary,
            loot: loot,
            label: goLabel,
            disabled: goDisabled,
            onTap: _go,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _Btn(
            variant: _BV.ghost,
            loot: loot,
            label: 'Cancel',
            onTap: close,
          ),
        ),
      ],
    );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_open,
        child: AnimatedOpacity(
          opacity: _open ? 1 : 0,
          duration: _ms(context, 200),
          curve: Curves.ease,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: close,
                  child: const ColoredBox(color: Color.fromRGBO(0, 0, 0, .7)),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    maxHeight: mq.size.height * .92,
                  ),
                  child: AnimatedContainer(
                    duration: _ms(context, 250),
                    curve: Curves.ease,
                    transform:
                        Matrix4.translationValues(0, _open ? 0 : 40, 0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D0D0D),
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                          border: Border(
                            top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                            left: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                            right:
                                BorderSide(color: Color(0xFF2A2A2A), width: 1),
                          ),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              18,
                              16,
                              18 +
                                  math.max(mq.padding.bottom,
                                      mq.viewInsets.bottom),
                            ),
                            child: panelBody,
                          ),
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

  Widget _chip(int v) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final s = '$v';
        _amt.value = TextEditingValue(
          text: s,
          selection: TextSelection.collapsed(offset: s.length),
        );
      },
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333), width: 1),
        ),
        child: Text('₹$v', style: _t(13, FontWeight.w600, _white, h: 1.5)),
      ),
    );
  }

  Widget _field() {
    final focused = _amtFocus.hasFocus;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? _c(76, 201, 170, .7) : const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text('₹',
              style: _t(17, FontWeight.w600, const Color(0xFFCBD0F0))),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _amt,
              focusNode: _amtFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 1,
              cursorColor: _white,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: _t(16, FontWeight.w500, _white),
              decoration: InputDecoration.collapsed(
                hintText: 'Enter amount',
                hintStyle: _t(16, FontWeight.w500, const Color(0xFF757575)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(bool loot) {
    Widget key(Color bg, Color? border, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(3),
              border: border == null ? null : Border.all(color: border, width: 1),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: _t(11, FontWeight.w400, _muted, h: 1.5)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          key(const Color(0xFF141414), const Color(0xFF333333), 'Free'),
          const SizedBox(width: 14),
          key(const Color(0xFF0A0A0A), const Color(0xFF1C1C1C), 'Booked'),
          const SizedBox(width: 14),
          key(loot ? _lootGold : const Color(0xFF22B08A), null, 'Yours'),
        ],
      ),
    );
  }
}

/// Red glass warning pill shown on top of the slot grid.
class _SlotWarn extends StatelessWidget {
  const _SlotWarn();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      r: 999,
      color: _c(28, 10, 10, .45),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color.fromRGBO(248, 113, 113, .3),
          Color.fromRGBO(153, 27, 27, .24),
        ],
      ),
      border: _c(252, 165, 165, .4),
      hl: _c(255, 255, 255, .26),
      shadows: const <_Sh>[_Sh(6, 18, Color.fromRGBO(0, 0, 0, .35))],
      blur: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          'Book kiye hue slot me hi rehna. Agar dusre slot me baithe to kick ho jaoge.',
          textAlign: TextAlign.center,
          style: _t(12, FontWeight.w600, const Color(0xFFFFE4E4), h: 1.5),
        ),
      ),
    );
  }
}