// lib/features/wallet/presentation/transactions_panel.dart
part of 'wallet_page.dart';

class TransactionsPanel extends StatefulWidget {
  const TransactionsPanel({
    super.key,
    required this.txs,
    required this.fresh,
    required this.born,
    required this.kind,
    required this.active,
    required this.onKind,
    required this.onAddMoney,
  });

  final List<WalletTx> txs;

  /// Rows that were just added (they pop in).
  final Set<WalletTx> fresh;

  /// When each row appeared (for the "verify in HH:MM:SS" countdown).
  final Map<WalletTx, DateTime> born;

  /// 'all' | 'added' | 'entry' | 'winning' | 'withdraw'
  final String kind;

  /// true while this panel is the visible one.
  final bool active;
  final ValueChanged<String> onKind;
  final VoidCallback onAddMoney;

  @override
  State<TransactionsPanel> createState() => _TransactionsPanelState();
}

class _TransactionsPanelState extends State<TransactionsPanel> {
  static const List<String> _kinds = <String>[
    'all',
    'added',
    'entry',
    'winning',
    'withdraw',
  ];
  static const List<String> _labels = <String>[
    'All',
    'Added',
    'Entry Fees',
    'Winnings',
    'Withdrawn',
  ];

  final List<GlobalKey> _tabKeys = List<GlobalKey>.generate(
    5,
    (_) => GlobalKey(),
  );
  final GlobalKey _rowKey = GlobalKey();
  double _thumbLeft = 0;
  double _thumbWidth = 0;
  bool _measured = false;

  // Measure the selected tab after layout and slide the thumb to it.
  void _measure() {
    if (!mounted) return;
    final idx = _kinds.indexOf(widget.kind);
    final tabCtx = _tabKeys[idx < 0 ? 0 : idx].currentContext;
    final rowCtx = _rowKey.currentContext;
    if (tabCtx == null || rowCtx == null) return;
    final tabBox = tabCtx.findRenderObject();
    final rowBox = rowCtx.findRenderObject();
    if (tabBox is! RenderBox || rowBox is! RenderBox) return;
    if (!tabBox.hasSize || !rowBox.hasSize || tabBox.size.width == 0) return;
    final left = tabBox.localToGlobal(Offset.zero, ancestor: rowBox).dx;
    final width = tabBox.size.width;
    if (!_measured ||
        (left - _thumbLeft).abs() > .5 ||
        (width - _thumbWidth).abs() > .5) {
      setState(() {
        _measured = true;
        _thumbLeft = left;
        _thumbWidth = width;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final kind = widget.kind;
    final list = kind == 'all'
        ? widget.txs
        : widget.txs.where((t) => t.kind == kind).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _H2('Transactions'),
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (_measured)
                  _slidingPositioned(
                    context: context,
                    left: _thumbLeft,
                    width: _thumbWidth,
                    top: 0,
                    height: 40,
                    child: _thumbBox(999),
                  ),
                Row(
                  key: _rowKey,
                  children: <Widget>[
                    for (var i = 0; i < _kinds.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: 8),
                      _TxTab(
                        key: _tabKeys[i],
                        label: _labels[i],
                        on: _kinds[i] == kind,
                        onTap: () => widget.onKind(_kinds[i]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: list.isEmpty
              ? _EmptyTx(onAdd: widget.onAddMoney)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final t in list)
                      _TxCard(
                        key: ObjectKey(t),
                        tx: t,
                        animateIn: widget.fresh.contains(t),
                        born: widget.born[t],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TxTab extends StatelessWidget {
  const _TxTab({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      scale: .93,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Colors.transparent : rsC(255, 255, 255, .06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? Colors.transparent : rsC(255, 255, 255, .12),
            width: 1,
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          alignment: Alignment.center,
          children: <Widget>[
            Center(
              widthFactor: 1,
              child: AnimatedDefaultTextStyle(
                duration: _ms(context, 400),
                style: _t(
                  13,
                  FontWeight.w500,
                  on ? const Color(0xFFEAFFF7) : const Color(0xFFC3D0CB),
                ),
                child: Text(label, maxLines: 1, softWrap: false),
              ),
            ),
            if (!on)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _HLPainter(19, rsC(255, 255, 255, .08)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTx extends StatelessWidget {
  const _EmptyTx({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 30, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rsC(76, 201, 170, .12),
              border: Border.all(color: rsC(110, 230, 195, .25), width: 1),
            ),
            child: _icon(_icWallet, '#6ee6c3', 30),
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: _t(17, FontWeight.w700, _white, h: 1.5),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 14),
            child: Text(
              'Your payments and winnings will show up here.',
              textAlign: TextAlign.center,
              style: _t(12, FontWeight.w400, _muted, h: 1.5),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: _Btn(
              variant: _BV.primary,
              label: 'Add Money',
              leading: _icon(_icPlus, '#eafff7', 17),
              onTap: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _TxCard extends StatefulWidget {
  const _TxCard({
    super.key,
    required this.tx,
    required this.animateIn,
    required this.born,
  });

  final WalletTx tx;
  final bool animateIn;
  final DateTime? born;

  @override
  State<_TxCard> createState() => _TxCardState();
}

class _TxCardState extends State<_TxCard> with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  bool _down = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animateIn && !MediaQuery.of(context).disableAnimations) {
      _intro.forward();
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  static Color _tint(String kind) {
    switch (kind) {
      case 'added':
        return rsC(76, 201, 170, .18);
      case 'entry':
        return rsC(168, 85, 247, .18);
      case 'winning':
        return rsC(251, 191, 36, .16);
      case 'withdraw':
        return rsC(239, 68, 68, .15);
      default:
        return rsC(255, 255, 255, .12);
    }
  }

  static Widget _kindIcon(String kind) {
    switch (kind) {
      case 'added':
        return _icon(_icPlus, '#6ee6c3', 20);
      case 'entry':
        return _icon(_icTicket, '#a855f7', 20);
      case 'winning':
        return _icon(_icTrophy, '#fbbf24', 20);
      case 'withdraw':
        return _icon(_icWallet, '#f87171', 20);
      case 'move':
        return _icon(_icArrow, '#ffffff', 20);
      default:
        return _icon(_icWallet, '#ffffff', 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tx;
    final plus =
        t.dir == 'in' || (t.kind == 'withdraw' && t.status == 'success');

    final Color stFg;
    final Color stBg;
    if (t.status == 'success') {
      stFg = _greenT;
      stBg = rsC(34, 197, 94, .14);
    } else if (t.status == 'pending') {
      stFg = _gold;
      stBg = rsC(251, 191, 36, .14);
    } else {
      stFg = _redT;
      stBg = rsC(239, 68, 68, .14);
    }
    final stLabel = t.status.isEmpty
        ? ''
        : t.status[0].toUpperCase() + t.status.substring(1);

    final card = _Pressable(
      scale: .985,
      dur: 250,
      onPress: (d) => setState(() => _down = d),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(
          end: _down ? rsC(110, 230, 195, .35) : rsC(255, 255, 255, .12),
        ),
        duration: _ms(context, 250),
        curve: kRsEase,
        builder: (context, border, _) {
          return _Surface(
            r: 22,
            color: _glassBase,
            gradient: _glassGrad,
            border: border,
            hl: rsC(255, 255, 255, .12),
            shadows: const <_Sh>[_Sh(6, 18, Color.fromRGBO(0, 0, 0, .3))],
            padding: const EdgeInsets.all(13),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tint(t.kind),
                    border: Border.all(
                      color: rsC(255, 255, 255, .14),
                      width: 1,
                    ),
                  ),
                  child: _kindIcon(t.kind),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        t.title,
                        style: _t(13, FontWeight.w700, _white, h: 1.3),
                      ),
                      _line(
                        24,
                        Text(t.date, style: _t(11, FontWeight.w400, _muted)),
                      ),
                      if (t.waitLeft != null)
                        _Countdown(
                          left: t.waitLeft!,
                          t0: widget.born ?? DateTime.now(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${plus ? '+' : '−'}₹${t.amt}',
                      style: _t(
                        14,
                        FontWeight.w700,
                        plus ? _greenT : _redT,
                        h: 1.5,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: stBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        stLabel,
                        style: _t(9, FontWeight.w600, stFg, h: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedBuilder(
        animation: _intro,
        child: card,
        builder: (context, child) {
          final v = Curves.ease.transform(_intro.value);
          return Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, -8 * (1 - v)),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// "Payment verify in HH:MM:SS" — ticks down every second.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.left, required this.t0});
  final int left;
  final DateTime t0;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsedMs = DateTime.now().difference(widget.t0).inMilliseconds;
    final s = math.max(((widget.left * 1000 - elapsedMs) / 1000).ceil(), 0);
    String p(int n) => n.toString().padLeft(2, '0');
    final text = s > 0
        ? 'Payment verify in ${p(s ~/ 3600)}:${p((s % 3600) ~/ 60)}:${p(s % 60)}'
        : 'Taking longer than usual. We are still checking it.';
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        text,
        style: _t(11, FontWeight.w600, _gold).copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
