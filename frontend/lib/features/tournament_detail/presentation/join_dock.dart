// lib/features/tournament_detail/presentation/join_dock.dart
part of 'tournament_detail_page.dart';

class JoinDock extends StatelessWidget {
  const JoinDock({
    super.key,
    required this.t,
    required this.balance,
    required this.gameOk,
    required this.joined,
    required this.loot,
    required this.onAdd,
    required this.onJoin,
    this.onBrowse,
    this.onViewMatches,
  });

  final TournamentDetail t;
  final int balance;
  final bool gameOk;
  final bool joined;
  final bool loot;
  final VoidCallback onAdd;
  final VoidCallback onJoin;
  final VoidCallback? onBrowse;
  final VoidCallback? onViewMatches;

  static const Color _low = Color(0xFFFBBF24);
  static const Color _okGreen = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final need = t.fee - balance;
    final live = t.isLive && !joined;
    final full = t.full && !joined && !live;
    final okColor = loot ? _lootGold : _okGreen;

    Widget body;
    if (joined) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
            child: Text('You have joined this tournament.',
                style: _t(12, FontWeight.w500, okColor, h: 1.5)),
          ),
          _Btn(
            variant: _BV.green,
            loot: loot,
            label: 'Joined • View in My Matches',
            iconPath: _icCheck,
            onTap: onViewMatches,
          ),
        ],
      );
    } else if (live) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('This match is live. Joining is closed.',
                style: _t(12, FontWeight.w500, _low, h: 1.5)),
          ),
          _Btn(
            variant: _BV.ghost,
            loot: loot,
            label: 'Browse upcoming tournaments',
            onTap: onBrowse,
          ),
        ],
      );
    } else {
      String needText;
      Color needColor;
      if (full) {
        needText = 'All slots are full';
        needColor = _low;
      } else if (!gameOk) {
        needText = 'Add your game name and UID in Profile to join';
        needColor = _low;
      } else if (need > 0) {
        needText = 'Add ₹${_inr(need)} more to join';
        needColor = _low;
      } else {
        needText = 'You have enough balance to join';
        needColor = okColor;
      }
      final joinOff = full || need > 0 || !gameOk;
      final infoStyle = _t(12, FontWeight.w400, const Color(0xFFBDBDBD), h: 1.5);
      final boldStyle = _t(12, FontWeight.w700, _white, h: 1.5);

      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text.rich(
                  TextSpan(style: infoStyle, children: <InlineSpan>[
                    const TextSpan(text: 'Entry fee '),
                    TextSpan(text: '₹${_inr(t.fee)}', style: boldStyle),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(style: infoStyle, children: <InlineSpan>[
                    const TextSpan(text: 'Your balance '),
                    TextSpan(text: '₹${_inr(balance)}', style: boldStyle),
                  ]),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
            child: Text(needText, style: _t(12, FontWeight.w500, needColor, h: 1.5)),
          ),
          Row(
            children: <Widget>[
              Expanded(
                flex: 11,
                child: _Btn(
                  variant: need > 0 ? _BV.primary : _BV.ghost,
                  loot: loot,
                  label: 'Add Money',
                  iconPath: _icPlus,
                  onTap: onAdd,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 13,
                child: _Btn(
                  variant: joinOff ? _BV.ghost : _BV.primary,
                  loot: loot,
                  off: joinOff,
                  label: full ? 'Slots full' : 'Join Now • ₹${_inr(t.fee)}',
                  onTap: onJoin,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 12 + bottom),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(0, 0, 0, .94),
                  border: Border(
                    top: BorderSide(color: Color(0xFF222222), width: 1),
                  ),
                ),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}