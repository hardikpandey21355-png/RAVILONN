import '../../../core/auth/api_client.dart';
import '../../../core/auth/auth_session.dart';
import 'wallet_mock.dart';

class WalletMutation {
  const WalletMutation({required this.wallet, required this.tx});

  final WalletState wallet;
  final WalletTx tx;
}

class WalletPaymentOrder {
  const WalletPaymentOrder({
    required this.orderId,
    required this.paymentUrl,
    required this.status,
  });

  final String orderId;
  final String paymentUrl;
  final String status;
}

class WalletPaymentStatus {
  const WalletPaymentStatus({required this.status, this.wallet});

  final String status;
  final WalletState? wallet;
}

class WalletRepository {
  WalletRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<WalletState> getWallet() async {
    final response = await _apiClient.getJson('/api/wallet');
    _requireOk(response);
    final wallet = _walletFromResponse(response);
    _applySession(wallet);
    return wallet;
  }

  Future<List<WalletTx>> getTransactions({String? kind, int limit = 50}) async {
    final response = await _apiClient.getJson(
      '/api/wallet/transactions',
      queryParameters: {
        if (kind != null && kind.isNotEmpty && kind != 'all') 'kind': kind,
        'limit': limit,
      },
    );
    _requireOk(response);
    final transactions = response['transactions'];
    if (transactions is! List) {
      throw const ApiAuthException(
        message: 'The server returned invalid transactions.',
      );
    }
    return transactions
        .whereType<Map>()
        .map((item) => _transactionFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<WalletMutation> depositRequest(int amount, String utr) =>
      _mutate('/api/wallet/deposit-request', {'amount': amount, 'utr': utr});

  Future<WalletPaymentOrder> createPaymentOrder(int amount) async {
    final response = await _apiClient.postJson(
      '/api/wallet/payment-orders',
      body: {'amount': amount},
    );
    _requireOk(response);
    final orderId = response['orderId'];
    final paymentUrl = response['paymentUrl'];
    final status = response['status'];
    if (orderId is! String || paymentUrl is! String || status is! String) {
      throw const ApiAuthException(
        message: 'The server returned an invalid payment order.',
      );
    }
    return WalletPaymentOrder(
      orderId: orderId,
      paymentUrl: paymentUrl,
      status: status,
    );
  }

  Future<WalletPaymentStatus> checkPaymentOrder(String orderId) async {
    final response = await _apiClient.getJson(
      '/api/wallet/payment-orders/${Uri.encodeComponent(orderId)}',
    );
    _requireOk(response);
    final status = response['status'];
    if (status is! String) {
      throw const ApiAuthException(
        message: 'The server returned an invalid payment status.',
      );
    }
    final rawWallet = response['wallet'];
    return WalletPaymentStatus(
      status: status,
      wallet: rawWallet is Map ? _walletFromResponse(response) : null,
    );
  }

  Future<WalletMutation> withdraw(int amount) =>
      _mutate('/api/wallet/withdraw', {'amount': amount});

  Future<WalletMutation> winningsToDeposit(int amount) =>
      _mutate('/api/wallet/winnings-to-deposit', {'amount': amount});

  Future<WalletMutation> _mutate(String path, Map<String, dynamic> body) async {
    final response = await _apiClient.postJson(path, body: body);
    _requireOk(response);
    final wallet = _walletFromResponse(response);
    _applySession(wallet);
    final tx = response['tx'];
    if (tx is! Map) {
      throw const ApiAuthException(
        message: 'The server returned an invalid transaction.',
      );
    }
    return WalletMutation(
      wallet: wallet,
      tx: _transactionFromJson(Map<String, dynamic>.from(tx)),
    );
  }

  WalletState _walletFromResponse(Map<String, dynamic> response) {
    final rawWallet = _asMap(response['wallet']);
    final limits = _asMap(response['limits']);
    final hasUpi = response['hasUpi'] is bool
        ? response['hasUpi'] as bool
        : AuthSession.hasUpi.value;
    final upi = response['upi'] is String
        ? response['upi'] as String
        : AuthSession.upi.value;
    final state = WalletState(
      deposited: _integer(rawWallet['deposited'], AuthSession.deposited.value),
      winnings: _integer(rawWallet['winnings'], AuthSession.winnings.value),
      bonus: _integer(rawWallet['bonus'], AuthSession.bonus.value),
      hasUpi: hasUpi,
      upi: upi,
      dailyLeft: _integer(response['dailyLeft'], AuthSession.dailyLeft.value),
      limits: WalletLimits(
        minAdd: _integer(limits['minAdd'], AuthSession.minAdd.value),
        maxAdd: _integer(limits['maxAdd'], AuthSession.maxAdd.value),
        minWithdraw: _integer(
          limits['minWithdraw'],
          AuthSession.minWithdraw.value,
        ),
        dailyLimit: _integer(
          limits['dailyLimit'],
          AuthSession.dailyLimit.value,
        ),
      ),
      paymentMethod: switch (response['paymentMethod']) {
        'gateway' => 'gateway',
        'manual' => 'manual',
        'off' => 'off',
        _ => AuthSession.paymentMethod.value,
      },
    );
    return state;
  }

  void _applySession(WalletState state) {
    AuthSession.applyWallet(
      deposited: state.deposited,
      winnings: state.winnings,
      bonus: state.bonus,
      dailyLeft: state.dailyLeft,
      minAdd: state.limits.minAdd,
      maxAdd: state.limits.maxAdd,
      minWithdraw: state.limits.minWithdraw,
      dailyLimit: state.limits.dailyLimit,
      upi: state.upi,
      hasUpi: state.hasUpi,
      paymentMethod: state.paymentMethod,
    );
  }

  WalletTx _transactionFromJson(Map<String, dynamic> json) {
    final status = json['status'] is String ? json['status'] as String : '';
    return WalletTx(
      id: json['id'] is String ? json['id'] as String : '',
      kind: json['kind'] is String ? json['kind'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      date: json['date'] is String ? json['date'] as String : '',
      amt: json['amt'] is String
          ? json['amt'] as String
          : _integer(json['amt'], 0).toString(),
      dir: json['dir'] is String ? json['dir'] as String : '',
      status: status == 'paid' ? 'success' : status,
      waitLeft: json['waitLeft'] is num
          ? (json['waitLeft'] as num).toInt()
          : null,
    );
  }

  void _requireOk(Map<String, dynamic> response) {
    if (response['ok'] == true) return;
    final error = response['error'];
    throw ApiAuthException(
      message: error is String && error.trim().isNotEmpty
          ? error.trim()
          : 'Something went wrong. Try again.',
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static int _integer(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }
}
