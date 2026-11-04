import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../mock/mock_data.dart';
import '../rs_kit.dart';

/// `_wallet.html` + the home override: frosted glass box, teal icon, balance, green plus.
class WalletChip extends StatelessWidget {
  const WalletChip({
    super.key,
    required this.balanceListenable,
    this.loot = false,
  });
  final ValueListenable<int> balanceListenable;
  final bool loot;

  @override
  Widget build(BuildContext context) {
    final alreadyOnWallet = ModalRoute.of(context)?.settings.name == '/wallet';
    return RsPress(
      onTap: alreadyOnWallet
          ? null
          : () => Navigator.of(context).pushNamed('/wallet'),
      child: RsGlass(
        radius: 18,
        blur: 22,
        base: loot ? const Color(0xFF0F0C05) : rsC(10, 16, 15, .5),
        gradient: loot
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [rsW(.16), rsW(.05)],
              ),
        border: loot ? rsC(247, 215, 116, .5) : rsW(.18),
        topLight: .2,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: loot ? rsC(247, 215, 116, .12) : rsC(76, 201, 170, .16),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: RsIcon(
                'wallet',
                size: 17,
                color: loot ? const Color(0xFFF7D774) : kRsG2,
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: balanceListenable,
              builder: (context, amount, _) =>
                  Text('₹ ${inr(amount)}', style: rsT(14, w: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: loot
                      ? [const Color(0xFFF7D774), const Color(0xFFA8730A)]
                      : [const Color(0xFF3FBF9F), kRsGd],
                ),
              ),
              alignment: Alignment.center,
              child: RsIcon(
                'plus',
                size: 15,
                color: loot ? const Color(0xFF3B2402) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
