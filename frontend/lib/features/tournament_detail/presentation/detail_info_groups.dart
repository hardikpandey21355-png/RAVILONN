// lib/features/tournament_detail/presentation/detail_info_groups.dart
part of 'tournament_detail_page.dart';

class DetailInfoGroups extends StatelessWidget {
  const DetailInfoGroups({super.key, required this.t});
  final TournamentDetail t;

  static const List<String> _rules = <String>[
    'Join with the same Free Fire name and UID as your profile.',
    'Room ID and password appear in My Matches 15 minutes before the start.',
    'Hacks, teaming up with other squads and fake accounts lead to disqualification.',
    'Prizes are added to your wallet after the results are declared.',
  ];

  @override
  Widget build(BuildContext context) {
    final showPrizes = t.prizes.isNotEmpty || t.hasPerKill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _H2('Match info'),
        _Group(
          children: <Widget>[
            _Li(label: 'Game', value: t.game),
            _Li(label: 'Mode', value: t.modeTitle),
            _Li(label: 'Team', value: t.team),
            _Li(label: 'Map', value: t.map),
            _Li(label: 'Start', value: t.when),
          ],
        ),
        if (showPrizes) ...<Widget>[
          const _H2('Prize distribution'),
          _Group(
            children: <Widget>[
              for (final p in t.prizes)
                _Li(label: '${p.$1} place', value: '₹${_inr(p.$2)}', gold: true),
              if (t.hasPerKill)
                _Li(
                  label: 'Reward per kill',
                  value: '₹${_inr(t.perKill!)}',
                  gold: true,
                ),
            ],
          ),
        ],
        const _H2('Rules'),
        _Group(
          children: <Widget>[
            for (final r in _rules)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _icon(_icCheck, '#4ade80', 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r,
                        style: _t(13, FontWeight.w400, const Color(0xFFD4D4D4),
                            h: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// `h2` (15px w600, margin 22/0/10)
class _H2 extends StatelessWidget {
  const _H2(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Text(text, style: _t(15, FontWeight.w600, _white, h: 1.5)),
    );
  }
}

/// `.group`: dark box with dividers (#1c1c1c) between rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(
        DecoratedBox(
          decoration: BoxDecoration(
            border: i == 0
                ? null
                : const Border(
                    top: BorderSide(color: Color(0xFF1C1C1C), width: 1),
                  ),
          ),
          child: children[i],
        ),
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _boxBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _boxLine, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// `.li`
class _Li extends StatelessWidget {
  const _Li({required this.label, required this.value, this.gold = false});
  final String label;
  final String value;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: _t(13, FontWeight.w400, const Color(0xFF9A9A9A), h: 1.5)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: _t(13, FontWeight.w500, gold ? _gold : _white, h: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}