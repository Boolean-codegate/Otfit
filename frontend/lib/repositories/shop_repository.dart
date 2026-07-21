import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../mock/mock_products.dart';
import '../models/product.dart';

/// 계약 §6 GET /results/{id}/shop 응답.
@immutable
class ShopInfo {
  const ShopInfo({required this.appliedProduct, required this.similarProducts});

  final Product appliedProduct;
  final List<Product> similarProducts;

  factory ShopInfo.fromJson(Map<String, dynamic> json) => ShopInfo(
    appliedProduct: Product.fromJson(
      Map<String, dynamic>.from(json['applied_product'] as Map),
    ),
    similarProducts: json['similar_products'] is List
        ? (json['similar_products'] as List)
              .whereType<Map>()
              .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
        : const <Product>[],
  );
}

/// 계약 §6 이벤트 type: result_view | result_save | result_share |
/// product_click | purchase_click
abstract final class EventTypes {
  static const String resultView = 'result_view';
  static const String resultSave = 'result_save';
  static const String resultShare = 'result_share';
  static const String productClick = 'product_click';
  static const String purchaseClick = 'purchase_click';
}

abstract class ShopRepository {
  /// Mirrors GET /results/{id}/shop.
  Future<ShopInfo> getShopForResult(String resultId);

  /// Mirrors POST /events (202). 실패해도 UI 흐름을 막지 않도록 호출부에서
  /// fire-and-forget 으로 사용한다.
  Future<void> recordEvent({
    required String type,
    String? sessionId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  });
}

class HttpShopRepository implements ShopRepository {
  HttpShopRepository(this._client);

  final ApiClient _client;

  @override
  Future<ShopInfo> getShopForResult(String resultId) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/results/$resultId/shop',
      );
      return ShopInfo.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<void> recordEvent({
    required String type,
    String? sessionId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    return guardApi(() async {
      await _client.dio.post<Map<String, dynamic>>(
        '/events',
        data: <String, dynamic>{
          'type': type,
          'session_id': ?sessionId,
          'payload': payload,
        },
      );
    });
  }
}

class MockShopRepository implements ShopRepository {
  @override
  Future<ShopInfo> getShopForResult(String resultId) async {
    final applied = mockProducts.first;
    return ShopInfo(
      appliedProduct: applied,
      similarProducts: mockProducts
          .where(
            (product) =>
                product.id != applied.id &&
                product.category == applied.category,
          )
          .take(4)
          .toList(growable: false),
    );
  }

  @override
  Future<void> recordEvent({
    required String type,
    String? sessionId,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {}
}
