import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/rs_kit.dart';
import '../../../core/widgets/wallet_chip.dart';
import '../data/loot_mock.dart';
import 'loot_hero.dart';
import 'loot_match_card.dart';
import 'loot_soon_card.dart';

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(
  double size,
  FontWeight w,
  Color color, {
  double ls = 0,
  double? h,
}) => rsT(size, w: w, color: color, ls: ls, h: h);

const Color _gold = Color(0xFFF7D774);
const Color _panel = Color(0xFF0F0C05);
const Color _mute = Color(0xFF8D92B8);
const Color _soft = Color(0xFFA89C78);
const Color _edge = Color.fromRGBO(247, 215, 116, .5);

class LootPage extends StatefulWidget {
  const LootPage({
    super.key,
    this.walletChip,
    this.cards,
    this.sunDate,
    this.canJoin = true,
    this.paidOk = true,
    this.joinedIds,
    this.onBack,
    this.onOpen,
    this.onPlayPaid,
    this.bottomInset = const EdgeInsets.only(bottom: 28),
    this.imageBase = 'assets/images/',
  });

  /// Header right side. Default is a simple gold-bordered "₹ 1,250" pill.
  final Widget? walletChip;

  /// An empty list shows the "Match coming soon" placeholders.
  final List<LootCard>? cards;

  /// Text next to "SUNDAY", e.g. 'Sunday, 2 Nov'.
  final String? sunDate;

  /// true on Sunday (India time).
  final bool canJoin;

  /// true when the player already played a paid match this week.
  final bool paidOk;

  /// Ids of the loot matches the player joined (the buttons turn into "Joined").
  final ValueListenable<Set<String>>? joinedIds;

  final VoidCallback? onBack;

  /// "Join Free" or "Joined" tapped.
  final void Function(String id)? onOpen;

  /// "Play 1 paid match first" tapped.
  final VoidCallback? onPlayPaid;

  /// Extra padding at the bottom (the page adds the safe area itself).
  final EdgeInsets bottomInset;

  /// 'assets/images/' (asset files) or 'https://.../static/images/' (network).
  final String imageBase;

  @override
  State<LootPage> createState() => _LootPageState();
}

class _LootPageState extends State<LootPage> {
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  final ValueNotifier<Set<String>> _noJoined = ValueNotifier<Set<String>>(
    const <String>{},
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick.value++);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick.dispose();
    _noJoined.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards ?? const <LootCard>[];
    final soon = cards.length >= 2 ? 0 : 2 - cards.length;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            14,
            14,
            14,
            0,
          ).add(widget.bottomInset).add(EdgeInsets.only(bottom: safeBottom)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 16),
                  const LootHero(),
                  const SizedBox(height: 14),
                  LootNotice(paidOk: widget.paidOk),
                  _dayHeading(),
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: widget.joinedIds ?? _noJoined,
                    builder: (_, joined, _) => Column(
                      children: [
                        for (final c in cards)
                          Padding(
                            key: ValueKey(c.id),
                            padding: const EdgeInsets.only(bottom: 14),
                            child: LootMatchCard(
                              card: c,
                              tick: _tick,
                              canJoin: widget.canJoin,
                              paidOk: widget.paidOk,
                              joined: joined.contains(c.id),
                              imageBase: widget.imageBase,
                              onOpen: widget.onOpen,
                              onPlayPaid: widget.onPlayPaid,
                            ),
                          ),
                        for (var i = 0; i < soon; i++)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 14),
                            child: LootSoonCard(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Room ID and password appear in My Matches after you join.\n'
                    'Rewards are added to your Winnings after the results.',
                    textAlign: TextAlign.center,
                    style: _t(11, FontWeight.w400, _soft, h: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final fs = (w * .05).clamp(18.0, 22.0).toDouble();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _panel,
                    border: Border.all(color: _edge),
                  ),
                  child: const RsIcon('back', size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Loot',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(fs, FontWeight.w700, Colors.white, h: 1.15),
                    ),
                    Text(
                      'Play Free • Win Real',
                      maxLines: 1,
                      style: _t(11, FontWeight.w400, _mute),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        widget.walletChip ??
            WalletChip(balanceListenable: AuthSession.walletTotal, loot: true),
      ],
    );
  }

  Widget _dayHeading() => Padding(
    padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
    child: Row(
      children: [
        Text('SUNDAY', style: _t(17, FontWeight.w700, _gold, ls: 2.38)),
        const SizedBox(width: 10),
        Text(
          widget.sunDate ?? nextLootSundayDate(),
          style: _t(11, FontWeight.w400, _soft),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _c(247, 215, 116, .5))),
      ],
    ),
  );
}
