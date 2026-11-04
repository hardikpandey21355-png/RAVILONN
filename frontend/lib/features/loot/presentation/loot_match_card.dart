import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/rs_kit.dart';
import '../../../core/mock/mock_data.dart' show rsClockWithDays;
import '../data/loot_mock.dart';
import 'loot_hero.dart' show LootGoldBox;

Color _c(int r, int g, int b, [double o = 1]) => rsC(r, g, b, o);
TextStyle _t(
  double size,
  FontWeight w,
  Color color, {
  double ls = 0,
  double? h,
}) => rsT(size, w: w, color: color, ls: ls, h: h);

const Color _gold = Color(0xFFF7D774);
const Color _gold2 = Color(0xFFD9A21F);
const Color _goldTxt = Color(0xFFFFE9A3);
const Color _ink = Color(0xFF3B2402);
const Color _mute = Color(0xFF8D92B8);

// ===================================================================== CARD
class LootMatchCard extends StatefulWidget {
  const LootMatchCard({
    super.key,
    required this.card,
    required this.tick,
    required this.canJoin,
    required this.paidOk,
    required this.joined,
    this.imageBase = 'assets/images/',
    this.onOpen,
    this.onPlayPaid,
  });

  final LootCard card;

  /// Changes every second; the countdown reads the clock again on every change.
  final ValueListenable<int> tick;
  final bool canJoin, paidOk, joined;

  /// 'assets/images/' (asset files) or 'https://.../static/images/' (network).
  final String imageBase;
  final void Function(String id)? onOpen;
  final VoidCallback? onPlayPaid;

  @override
  State<LootMatchCard> createState() => _LootMatchCardState();
}

class _LootMatchCardState extends State<LootMatchCard> {
  DateTime _base = DateTime.now();

  @override
  void didUpdateWidget(LootMatchCard old) {
    super.didUpdateWidget(old);
    if (old.card.secs != widget.card.secs) _base = DateTime.now();
  }

  /// Counts down from the server value, stops at 0.
  int _left() {
    final v = widget.card.secs - DateTime.now().difference(_base).inSeconds;
    return v < 0 ? 0 : v;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final hasKill = c.perKill != null && c.perKill!.isNotEmpty;
    final hasFirst = c.first != null && c.first!.isNotEmpty;
    final boxes = <Widget>[
      _Stat(value: _valueText(c.prize), label: 'Prize Pool'),
      if (hasKill)
        _Stat(value: _valueText('${c.perKill} / kill'), label: 'Per Kill')
      else if (hasFirst)
        _Stat(value: _valueText(c.first!), label: '1st Prize'),
      _Stat(value: _valueText(c.players), label: 'Players'),
      _Stat(
        value: ValueListenableBuilder<int>(
          valueListenable: widget.tick,
          builder: (_, _, _) => _valueText(rsClockWithDays(_left())),
        ),
        label: c.label,
      ),
    ];

    return LootGoldBox(
      radius: 22,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _imageArea(c),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statsGrid(boxes),
                const SizedBox(height: 12),
                _action(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Text _valueText(String s) => Text(
    s,
    maxLines: 1,
    softWrap: false,
    style: _t(
      14,
      FontWeight.w700,
      _gold,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  );

  Widget _statsGrid(List<Widget> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[i]),
            const SizedBox(width: 8),
            Expanded(
              child: i + 1 < items.length
                  ? items[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  // ---------------------------------------------------------- image area
  Widget _img() {
    final path = widget.card.imageUrl.isNotEmpty
        ? widget.card.imageUrl
        : '${widget.imageBase}${widget.card.img}';
    Widget err(BuildContext ctx, Object e, StackTrace? s) {
      debugPrint('LootMatchCard: image could not load: $path ($e)');
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF241A06), Color(0xFF0F0C05)],
          ),
        ),
      );
    }

    return widget.card.imageUrl.startsWith('http') ||
            widget.imageBase.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover, errorBuilder: err)
        : Image.asset(path, fit: BoxFit.cover, errorBuilder: err);
  }

  Widget _imageArea(LootCard c) {
    final showRoom =
        widget.joined && c.roomId.isNotEmpty && c.roomPass.isNotEmpty;
    return SizedBox(
      height: showRoom ? 205 : 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF111111)),
          Positioned.fill(child: _img()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_c(12, 12, 20, .95), _c(0, 0, 0, .15)],
                  stops: const [.04, .7],
                ),
              ),
            ),
          ),
          if (c.status == 'live')
            const Positioned(top: 8, left: 8, child: _LiveTag()),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_gold2, _gold, Color(0xFFFFF0B0)],
                  stops: [0, .55, 1],
                ),
              ),
              child: Text('FREE', style: _t(10, FontWeight.w800, _ink, ls: 2)),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.mode, style: _t(18, FontWeight.w700, _goldTxt, h: 1.2)),
                Text(
                  '${c.team} | ${c.map} • ${c.time}',
                  style: _t(11, FontWeight.w400, const Color(0xFFB9BDDB)),
                ),
                if (showRoom) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _RoomBannerValue(
                          label: 'ROOM ID',
                          value: c.roomId,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RoomBannerValue(
                          label: 'PASSWORD',
                          value: c.roomPass,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- action button (same order as the template)
  Widget _action(LootCard c) {
    if (c.status == 'live') {
      return Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _c(239, 68, 68, .1),
          border: Border.all(color: _c(239, 68, 68, .45)),
        ),
        child: Text(
          'Match in progress',
          style: _t(12, FontWeight.w600, const Color(0xFFFCA5A5)),
        ),
      );
    }
    if (widget.canJoin && !widget.paidOk) {
      return _GoldBtn(
        label: 'Play 1 paid match first',
        leading: 'lock',
        onTap: widget.onPlayPaid,
        press: false,
      );
    }
    if (widget.canJoin && widget.paidOk && widget.joined) {
      return _GoldBtn(
        label: 'Joined',
        leading: 'check',
        joined: true,
        onTap: widget.onOpen == null ? null : () => widget.onOpen!(c.id),
      );
    }
    if (widget.canJoin && widget.paidOk) {
      return _GoldBtn(
        label: 'Join Free',
        trailing: 'arrow',
        onTap: widget.onOpen == null ? null : () => widget.onOpen!(c.id),
      );
    }
    return const _GoldBtn(
      label: 'Come on Sunday',
      leading: 'lock',
      press: false,
    );
  }
}

class _RoomBannerValue extends StatelessWidget {
  const _RoomBannerValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xCC0F0C05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _c(247, 215, 116, .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _t(8, FontWeight.w600, _mute, ls: 1)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _t(12, FontWeight.w700, _goldTxt),
        ),
      ],
    ),
  );
}

// ===================================================================== PARTS
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final Widget value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _c(247, 215, 116, .06),
        border: Border.all(color: _c(247, 215, 116, .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          value,
          Text(label, style: _t(10, FontWeight.w400, _mute)),
        ],
      ),
    );
  }
}

/// The big gold pill. [press] = squeezes to 96% on tap. onTap null = not tappable.
class _GoldBtn extends StatelessWidget {
  const _GoldBtn({
    required this.label,
    this.leading,
    this.trailing,
    this.joined = false,
    this.onTap,
    this.press = true,
  });
  final String label;
  final String? leading, trailing;
  final bool joined, press;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = joined ? _gold : _ink;
    final iconColor = joined ? _gold : _ink;
    final btn = Container(
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: joined ? _c(247, 215, 116, .12) : null,
        gradient: joined
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF0B0), _gold, _gold2],
                stops: [0, .45, 1],
              ),
        border: joined ? Border.all(color: _c(247, 215, 116, .6)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            RsIcon(leading!, size: 15, color: iconColor),
            const SizedBox(width: 6),
          ],
          Text(label, style: _t(14, FontWeight.w700, fg)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            RsIcon(trailing!, size: 15, color: iconColor),
          ],
        ],
      ),
    );
    if (onTap == null) return btn;
    if (!press) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: btn,
      );
    }
    return RsPress(
      scale: .96,
      duration: const Duration(milliseconds: 200),
      onTap: onTap,
      child: btn,
    );
  }
}

/// Red "LIVE" tag with a blinking white dot (1.2s).
class _LiveTag extends StatefulWidget {
  const _LiveTag();
  @override
  State<_LiveTag> createState() => _LiveTagState();
}

class _LiveTagState extends State<_LiveTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.stop();
      _ctl.value = 0;
    } else if (!_ctl.isAnimating) {
      _ctl.repeat();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFDC2626),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, _) => Opacity(
              opacity: .3 + .7 * (2 * _ctl.value - 1).abs(),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text('LIVE', style: _t(9, FontWeight.w600, Colors.white)),
        ],
      ),
    );
  }
}
