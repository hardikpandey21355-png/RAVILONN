// lib/main_demo_wallet.dart
//
// Run alone:  flutter run -t lib/main_demo_wallet.dart

import 'package:flutter/material.dart';

import 'features/wallet/presentation/wallet_page.dart';

void main() {
  runApp(const _WalletDemoApp());
}

class _WalletDemoApp extends StatelessWidget {
  const _WalletDemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: WalletPage(
        // initialPayStatus: 'paid', // 'paid' | 'pending' | 'failed'
        onTotalChanged: (total) => debugPrint('wallet total: $total'),
        onOpenProfile: () => debugPrint('open profile'),
      ),
    );
  }
}