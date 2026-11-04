// lib/features/tournament_detail/presentation/detail_facts.dart
part of 'tournament_detail_page.dart';

class DetailFacts extends StatelessWidget {
  const DetailFacts({super.key, required this.t});
  final TournamentDetail t;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _Fact(
        icon: _icTrophy,
        hex: '#fbbf24',
        value: '₹${_inr(t.prize)}',
        label: 'Prize Pool',
      ),
      _Fact(
        icon: _icTicket,
        hex: '#3b82f6',
        value: '₹${_inr(t.fee)}',
        label: 'Entry Fee',
      ),
      _Fact(
        icon: _icUsers,
        hex: '#22d3ee',
        value: '${t.joinedCount} / ${t.slots}',
        label: 'Players',
      ),
      if (t.hasPerKill)
        _Fact(
          icon: _icSwords,
          hex: '#ffffff',
          value: '₹${_inr(t.perKill!)}',
          label: 'Per Kill',
        ),
      _TimerFact(secs: t.secs, label: t.label),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final right = i + 1 < items.length ? items[i + 1] : const SizedBox();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: items[i]),
                const SizedBox(width: 10),
                Expanded(child: right),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...rows,
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _SlotsBar(t: t),
        ),
      ],
    );
  }
}

/// `.fact` / `.slots` / `.group` box.
class _Box extends StatelessWidget {
  const _Box({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _boxBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _boxLine, width: 1),
      ),
      child: child,
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.hex,
    required this.value,
    required this.label,
  });

  final String icon;
  final String hex;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _Box(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              _icon(icon, hex, 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: _t(18, FontWeight.w600, _white, h: 1.5),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(label, style: _t(11, FontWeight.w400, _muted, h: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// HH:MM:SS box, counts down every second.
class _TimerFact extends StatefulWidget {
  const _TimerFact({required this.secs, required this.label});
  final int secs;
  final String label;

  @override
  State<_TimerFact> createState() => _TimerFactState();
}

class _TimerFactState extends State<_TimerFact> {
  late int _left = widget.secs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left > 0) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Box(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _rsClock(_left),
            maxLines: 1,
            softWrap: false,
            style: _t(18, FontWeight.w600, _white, h: 1.5),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(widget.label,
                style: _t(11, FontWeight.w400, _muted, h: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _SlotsBar extends StatelessWidget {
  const _SlotsBar({required this.t});
  final TournamentDetail t;

  @override
  Widget build(BuildContext context) {
    final left = t.slots - t.joinedCount;
    final pct = t.slots == 0 ? 0 : (t.joinedCount * 100) ~/ t.slots;
    final frac = t.slots == 0 ? 0.0 : (t.joinedCount / t.slots).clamp(0.0, 1.0);
    const rowStyleColor = Color(0xFFBDBDBD);

    return _Box(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('$left slots left',
                    style: _t(12, FontWeight.w400, rowStyleColor, h: 1.5)),
                Text('$pct% full',
                    style: _t(12, FontWeight.w400, rowStyleColor, h: 1.5)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: const Color(0xFF222222),
              alignment: Alignment.centerLeft,
              child: LayoutBuilder(
                builder: (context, c) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: frac),
                    duration: _ms(context, 400),
                    curve: Curves.ease,
                    builder: (context, v, _) {
                      final minW = t.joinedCount > 0 ? 6.0 : 0.0;
                      final w = math.max(c.maxWidth * v, minW);
                      return Container(
                        width: w,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: <Color>[
                              Color(0xFFEF4444),
                              Color(0xFFF87171),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}