// Run alone:  flutter run -t lib/main_demo_profile.dart
import 'package:flutter/material.dart';

import 'core/mock/mock_data.dart';
import 'core/widgets/wallet_chip.dart';
import 'features/profile/data/profile_mock.dart';
import 'features/profile/presentation/profile_page.dart';

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Profile demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: ProfilePage(
        walletChip: WalletChip(balanceListenable: MockData.walletBalance),
        userName: kMockUserName,
        userEmail: kMockUserEmail,
        pictureUrl: kMockPictureUrl,
        initialGame: kMockGame,
        initialUpi: kMockUpi,
        onOpenUrl: (u) async {},
        onOpenWallet: () {},
        onLogout: () async {},
      ),
    );
  }
}
