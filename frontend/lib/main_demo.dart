import 'package:flutter/material.dart';

import 'core/mock/mock_data.dart';
import 'core/widgets/wallet_chip.dart';
import 'features/tournaments/presentation/tournaments_page.dart';

// Run with:  flutter run -t lib/main_demo.dart
void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: TournamentsPage(
          walletChip: WalletChip(balanceListenable: MockData.walletBalance),
          joinedIds: MockData.joinedIds,
          onBack: () => debugPrint('back'),
          onOpen: (id) {
            debugPrint('open $id');
            MockData.joinedIds.value = <String>{
              ...MockData.joinedIds.value,
              id,
            };
          },
        ),
      ),
    );
  }
}
