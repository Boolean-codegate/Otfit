import '../core/network/api_client.dart';
import '../models/consent.dart';

/// 계약 §2: POST /consents, GET /consents
abstract class ConsentRepository {
  Future<Consent> upsert({required String type, required bool granted});

  Future<List<Consent>> list();
}

class HttpConsentRepository implements ConsentRepository {
  HttpConsentRepository(this._client);

  final ApiClient _client;

  @override
  Future<Consent> upsert({required String type, required bool granted}) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/consents',
        data: <String, dynamic>{'type': type, 'granted': granted},
      );
      return Consent.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<List<Consent>> list() {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>('/consents');
      final items = response.data?['items'];
      if (items is! List) return const <Consent>[];
      return items
          .whereType<Map>()
          .map((item) => Consent.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }
}

class MockConsentRepository implements ConsentRepository {
  final Map<String, Consent> _consents = <String, Consent>{};
  int _sequence = 0;

  @override
  Future<Consent> upsert({required String type, required bool granted}) async {
    final consent = Consent(
      id: _consents[type]?.id ?? 'c_mock_${++_sequence}',
      type: type,
      granted: granted,
      grantedAt: granted ? DateTime.now().toUtc() : null,
    );
    _consents[type] = consent;
    return consent;
  }

  @override
  Future<List<Consent>> list() async =>
      _consents.values.toList(growable: false);
}
