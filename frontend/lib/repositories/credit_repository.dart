import '../core/network/api_client.dart';

/// 계약 §8: GET /credits, POST /credits/purchase (결제는 목)
abstract class CreditRepository {
  Future<int> getBalance();

  /// returns (새 잔액, 거래 id)
  Future<({int balance, String transactionId})> purchase(int amount);
}

class HttpCreditRepository implements CreditRepository {
  HttpCreditRepository(this._client);

  final ApiClient _client;

  @override
  Future<int> getBalance() {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>('/credits');
      return (response.data?['balance'] as num?)?.toInt() ?? 0;
    });
  }

  @override
  Future<({int balance, String transactionId})> purchase(int amount) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/credits/purchase',
        data: <String, dynamic>{'amount': amount},
      );
      final data = response.data ?? const <String, dynamic>{};
      return (
        balance: (data['balance'] as num?)?.toInt() ?? 0,
        transactionId: (data['transaction_id'] ?? '').toString(),
      );
    });
  }
}

class MockCreditRepository implements CreditRepository {
  int _balance = 30;
  int _sequence = 0;

  @override
  Future<int> getBalance() async => _balance;

  @override
  Future<({int balance, String transactionId})> purchase(int amount) async {
    _balance += amount;
    return (balance: _balance, transactionId: 'tx_mock_${++_sequence}');
  }
}
