// lib/features/wallet/data/wallet_mock.dart
//
// Models, config constants and mock data for the Wallet page (UI only).

import 'package:flutter/foundation.dart';

/// Limits used by the wallet UI (same values as the Flask config).
class WalletConfig {
  const WalletConfig._();

  static const int minAdd = 1;
  static const int maxAdd = 100;
  static const int minWithdraw = 20;
  static const int dailyLimit = 100;
}

@immutable
class WalletLimits {
  const WalletLimits({
    this.minAdd = WalletConfig.minAdd,
    this.maxAdd = WalletConfig.maxAdd,
    this.minWithdraw = WalletConfig.minWithdraw,
    this.dailyLimit = WalletConfig.dailyLimit,
  });

  final int minAdd;
  final int maxAdd;
  final int minWithdraw;
  final int dailyLimit;
}

@immutable
class WalletState {
  const WalletState({
    required this.deposited,
    required this.winnings,
    this.bonus = 0,
    required this.hasUpi,
    this.upi = '',
    required this.dailyLeft,
    this.limits = const WalletLimits(),
    this.paymentMethod = 'gateway',
  });

  final int deposited;
  final int winnings;
  final int bonus;
  final bool hasUpi;
  final String upi;
  final int dailyLeft;
  final WalletLimits limits;
  final String paymentMethod;

  int get total => deposited + winnings + bonus;

  WalletState copyWith({
    int? deposited,
    int? winnings,
    int? bonus,
    bool? hasUpi,
    String? upi,
    int? dailyLeft,
    WalletLimits? limits,
    String? paymentMethod,
  }) {
    return WalletState(
      deposited: deposited ?? this.deposited,
      winnings: winnings ?? this.winnings,
      bonus: bonus ?? this.bonus,
      hasUpi: hasUpi ?? this.hasUpi,
      upi: upi ?? this.upi,
      dailyLeft: dailyLeft ?? this.dailyLeft,
      limits: limits ?? this.limits,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

/// One row of the Transactions list.
///
/// kind:   'added' | 'entry' | 'winning' | 'withdraw' | 'move'
/// dir:    'in' | 'out'
/// status: 'success' | 'pending' | 'failed'
/// amt:    already formatted string, e.g. '100' or '1,250'
/// waitLeft: seconds left before a pending payment is verified (or null)
@immutable
class WalletTx {
  const WalletTx({
    this.id = '',
    required this.kind,
    required this.title,
    required this.date,
    required this.amt,
    required this.dir,
    required this.status,
    this.waitLeft,
  });

  final String id;
  final String kind;
  final String title;
  final String date;
  final String amt;
  final String dir;
  final String status;
  final int? waitLeft;
}

/// Result of the "Add" payment (returned by `WalletPage.onPay`).
@immutable
class PayResult {
  const PayResult._({
    required this.ok,
    this.cancelled = false,
    this.error,
    this.wallet,
    this.tx,
  });

  /// Payment went through (or was sent for approval).
  /// Optionally pass the new wallet / the transaction row to show.
  const PayResult.success({WalletState? wallet, WalletTx? tx})
    : this._(ok: true, wallet: wallet, tx: tx);

  /// The user closed the payment screen.
  const PayResult.cancelled() : this._(ok: false, cancelled: true);

  /// Something went wrong. [error] is shown in the toast (optional).
  const PayResult.failure([String? error]) : this._(ok: false, error: error);

  final bool ok;
  final bool cancelled;
  final String? error;
  final WalletState? wallet;
  final WalletTx? tx;
}

class WalletMock {
  const WalletMock._();

  static const WalletState initialState = WalletState(
    deposited: 850,
    winnings: 400,
    hasUpi: false,
    upi: '',
    dailyLeft: 100,
  );

  static WalletState currentState = initialState;

  /// Mock payment: succeeds after 700 ms (sent for approval).
  static Future<PayResult> pay(int amount) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const PayResult.success();
  }

  static List<WalletTx> transactions() {
    return <WalletTx>[
      WalletTx(
        kind: 'added',
        title: 'Money added',
        date: '31 Oct, 11:20 AM',
        amt: '100',
        dir: 'in',
        status: 'success',
      ),
      WalletTx(
        kind: 'added',
        title: 'Money added',
        date: '31 Oct, 09:05 AM',
        amt: '50',
        dir: 'in',
        status: 'pending',
        waitLeft: 9000, // 2h 30m
      ),
      WalletTx(
        kind: 'entry',
        title: 'Match entry fee',
        date: '30 Oct, 08:40 PM',
        amt: '30',
        dir: 'out',
        status: 'success',
      ),
      WalletTx(
        kind: 'winning',
        title: 'Match winnings',
        date: '30 Oct, 09:15 PM',
        amt: '120',
        dir: 'in',
        status: 'success',
      ),
      WalletTx(
        kind: 'withdraw',
        title: 'Withdrawal paid',
        date: '29 Oct, 06:30 PM',
        amt: '100',
        dir: 'out',
        status: 'success',
      ),
      WalletTx(
        kind: 'withdraw',
        title: 'Withdrawal requested',
        date: '29 Oct, 10:12 AM',
        amt: '50',
        dir: 'out',
        status: 'pending',
      ),
      WalletTx(
        kind: 'withdraw',
        title: 'Withdrawal failed',
        date: '28 Oct, 04:45 PM',
        amt: '40',
        dir: 'out',
        status: 'failed',
      ),
      WalletTx(
        kind: 'move',
        title: 'Winnings moved to deposit',
        date: '27 Oct, 02:10 PM',
        amt: '50',
        dir: 'in',
        status: 'success',
      ),
      WalletTx(
        kind: 'added',
        title: 'Money added',
        date: '26 Oct, 07:55 PM',
        amt: '200',
        dir: 'in',
        status: 'success',
      ),
    ];
  }
}
