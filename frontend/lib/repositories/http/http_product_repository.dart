import '../../core/network/api_client.dart';
import '../../models/product.dart';
import '../product_repository.dart';

/// 계약 §4 GET /products (필터·cursor 페이지네이션) 구현.
class HttpProductRepository extends ProductRepository {
  HttpProductRepository(this._client);

  final ApiClient _client;

  /// `/products/{id}` 라우트가 계약에 없으므로, 조회했던 목록을 캐시해서
  /// [getProductById]를 해결한다.
  final Map<String, Product> _cache = <String, Product>{};

  @override
  Future<ProductPage> fetchProducts({
    String? category,
    String? brand,
    int? minPrice,
    int? maxPrice,
    int limit = 20,
    String? cursor,
  }) {
    return guardApi(() async {
      final apiCategory = category == null
          ? null
          : ProductCategories.apiValueFor(category);
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/products',
        queryParameters: <String, dynamic>{
          'category': ?apiCategory,
          if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
          'min_price': ?minPrice,
          'max_price': ?maxPrice,
          'limit': limit,
          'cursor': ?cursor,
        },
      );
      final page = ProductPage.fromJson(
        response.data ?? const <String, dynamic>{},
      );
      for (final product in page.items) {
        _cache[product.id] = product;
      }
      return page;
    });
  }

  @override
  Future<Product?> getProductById(String id) async {
    final cached = _cache[id];
    if (cached != null) return cached;

    // 캐시에 없으면 목록을 순회하며 찾는다 (시드 40개 규모라 1~2 페이지면 충분).
    String? cursor;
    for (var pageCount = 0; pageCount < 5; pageCount++) {
      final page = await fetchProducts(limit: 100, cursor: cursor);
      final match = _cache[id];
      if (match != null) return match;
      cursor = page.nextCursor;
      if (cursor == null) break;
    }
    return _cache[id];
  }
}
