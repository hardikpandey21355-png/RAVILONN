// lib/features/tournament_detail/presentation/slot_grid.dart
part of 'tournament_detail_page.dart';

class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.loading,
    required this.failed,
    required this.slots,
    required this.teamSize,
    required this.taken,
    required this.picked,
    required this.loot,
    required this.onPick,
  });

  final bool loading;
  final bool failed;
  final int slots;
  final int teamSize;
  final Set<int> taken;
  final int picked;
  final bool loot;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    if (loading || failed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              loading
                  ? 'Loading slots…'
                  : 'Could not load slots. Close and try again.',
              textAlign: TextAlign.center,
              style: _t(12, FontWeight.w400, _muted, h: 1.5),
            ),
          ),
        ),
      );
    }

    if (teamSize == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
        child: GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            mainAxisExtent: 34,
          ),
          itemBuilder: (context, i) => _slotButton(i + 1),
        ),
      );
    }

    final minimumGroupWidth = teamSize * 34 + (teamSize - 1) * 8 + 14;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              ((constraints.maxWidth + 10) / (minimumGroupWidth + 10))
                  .floor()
                  .clamp(1, 3);
          return GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (slots + teamSize - 1) ~/ teamSize,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 66,
            ),
            itemBuilder: (context, teamIndex) {
              final firstSlot = teamIndex * teamSize + 1;
              final lastSlot = (firstSlot + teamSize - 1)
                  .clamp(1, slots)
                  .toInt();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                decoration: BoxDecoration(
                  color: loot
                      ? _c(247, 215, 116, .045)
                      : _c(76, 201, 170, .045),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: loot
                        ? _c(247, 215, 116, .16)
                        : _c(76, 201, 170, .14),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TEAM ${teamIndex + 1}',
                      style: _t(8, FontWeight.w600, _muted),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (
                          var slot = firstSlot;
                          slot <= lastSlot;
                          slot++
                        ) ...[
                          if (slot > firstSlot) const SizedBox(width: 8),
                          _slotButton(slot),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _slotButton(int number) => SizedBox(
    width: 34,
    height: 34,
    child: _SlotButton(
      n: number,
      taken: taken.contains(number),
      on: picked == number,
      loot: loot,
      onTap: () => onPick(number),
    ),
  );
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.n,
    required this.taken,
    required this.on,
    required this.loot,
    required this.onTap,
  });

  final int n;
  final bool taken;
  final bool on;
  final bool loot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? bg = const Color(0xFF141414);
    Gradient? grad;
    Color border = const Color(0xFF333333);
    Color fg = _white;
    bool glow = false;

    if (taken) {
      bg = const Color(0xFF0A0A0A);
      border = const Color(0xFF1C1C1C);
      fg = const Color(0xFF4A4A4A);
    } else if (on) {
      if (loot) {
        bg = _c(247, 215, 116, .18);
        border = _lootGold;
        fg = const Color(0xFFFFE9A3);
      } else {
        bg = null;
        grad = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color.fromRGBO(110, 230, 195, .35),
            Color.fromRGBO(27, 111, 92, .3),
          ],
        );
        border = _c(140, 240, 210, .7);
        fg = const Color(0xFFEAFFF7);
        glow = true;
      }
    }

    final box = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: glow ? 1.0 : 0.0),
      duration: _ms(context, 200),
      curve: Curves.ease,
      builder: (context, g, _) {
        return CustomPaint(
          painter: _ShadowPainter(9, <_Sh>[
            _Sh(0, 14, _c(76, 201, 170, .35 * g)),
          ]),
          child: AnimatedContainer(
            duration: _ms(context, 200),
            curve: Curves.ease,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              gradient: grad,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: border, width: 1),
            ),
            child: Text(
              '$n',
              style: _t(12, FontWeight.w600, fg).copyWith(
                decoration: taken
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: fg,
              ),
            ),
          ),
        );
      },
    );

    if (taken) return box;
    return RsPress(
      scale: .92,
      duration: const Duration(milliseconds: 200),
      onTap: onTap,
      child: box,
    );
  }
}
