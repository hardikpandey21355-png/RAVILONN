import 'package:flutter/material.dart';

import 'profile_group.dart';

const String _lock = '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>';

class RulesSheet extends StatelessWidget {
  const RulesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSheetPanel(
      icon: _lock,
      title: 'Rules and regulations',
      small: 'Please read before you play',
      body: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SheetH4('1. Eligibility', first: true),
        SheetList([
          'You must be 18 years or older to join paid tournaments and use the wallet.',
          'One person can have one account. Duplicate or fake accounts are not allowed.',
          'Paid-entry tournaments may not be allowed in every state. You are responsible for following the laws where you live.',
        ]),
        SheetH4('2. Game ID'),
        SheetList([
          'You must save your Free Fire in-game name and UID in Profile before you can join any match.',
          'Use your own name and UID, exactly as they appear in the game. Rewards go to the UID saved on your profile.',
          'Do not change your Game ID while you have a joined match that is not finished.',
        ]),
        SheetH4('3. Joining a match'),
        SheetList([
          'The entry fee, prize pool, slots and start time are shown on the tournament page before you join.',
          'Slots are first come, first served. When all slots are full, no more players can join.',
          'You can leave a match before it starts from My Matches.',
        ]),
        SheetH4('4. Room ID and playing the match'),
        SheetList([
          'The Room ID and password appear in My Matches 15 minutes before the match starts.',
          'Join the room on time with the same name and UID as your profile. Late players may not get a slot.',
          'Do not share the Room ID or password with anyone who has not joined the match.',
        ]),
        SheetH4('5. Fair play'),
        SheetList([
          'Hacks, cheats, mods, scripts and any unfair tools are strictly banned.',
          'Teaming up with other players or squads, ghosting and stream sniping are not allowed.',
          'Do not abuse game bugs or glitches to gain an advantage.',
          'Abusive or threatening behaviour towards other players or our team is not tolerated.',
          'Anyone who breaks these rules can be disqualified, lose their prize and have their account suspended.',
        ]),
        SheetH4('6. Results and prizes'),
        SheetList([
          'Results are declared after the match ends, based on the in-game result.',
          'The prize pool for each tournament is shared between the top three: 50% for 1st, 30% for 2nd and 20% for 3rd.',
          'Prizes are added to your Winnings balance after the results are declared.',
          'If you think a result is wrong, contact support with a screenshot. Our decision after review is final.',
        ]),
        SheetH4('7. Wallet and withdrawals'),
        SheetList([
          'You can add between ₹5 and ₹100 in one payment.',
          'Only your Winnings balance can be withdrawn. Money you added cannot be withdrawn.',
          'You can withdraw ₹20 - ₹100 at a time, and the daily limit is ₹100 in total. It is sent to the UPI ID saved in your Profile. A withdrawal shows as Pending until it is processed.',
          'UPI and KYC verification are needed before your first withdrawal.',
        ]),
        SheetH4('8. Cancellations and refunds'),
        SheetList([
          'If we cancel a tournament, the entry fee is returned to your wallet.',
          'If we reschedule a tournament, your entry stays valid for the new time.',
          'The entry fee is not refunded if you miss the match, join late or are disqualified.',
          'If a payment fails, your wallet balance does not change. If money was taken from your bank, contact support.',
        ]),
        SheetH4('9. Account actions'),
        SheetList([
          'We may warn, suspend or close accounts for rule violations, suspicious payments or misuse of the app.',
          'We may hold wallet withdrawals while we review an account.',
        ]),
        SheetH4('10. Responsible gaming'),
        SheetList([
          'Play for fun and skill. Only spend what you can afford to lose.',
          'If gaming starts to affect your studies, work, money or mood, take a break and stop joining paid matches.',
        ]),
        SheetH4('11. Changes to these rules'),
        SheetP(
            'We may update these rules from time to time. Using RudelySmash after an update means you accept the updated rules.'),
      ]),
      actions: [
        ProfileButton(label: 'Close', kind: ProfileButtonKind.ghost, onTap: () => Navigator.of(context).maybePop()),
      ],
    );
  }
}