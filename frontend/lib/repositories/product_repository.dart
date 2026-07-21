import '../core/config/app_config.dart';
import '../mock/mock_products.dart';
import '../models/product.dart';

abstract class ProductRepository {
  /// A future HTTP implementation should read [AppConfig.apiBaseUrl]. Provider
  /// wiring can then swap repositories without changing feature code.
  /// Mirrors GET /products, including cursor pagination.
  Future<ProductPage> fetchProducts({
    String? category,
    String? brand,
    int? minPrice,
    int? maxPrice,
    int limit = 20,
    String? cursor,
  });

  /// UI convenience that unwraps [ProductPage] and applies local text search.
  Future<List<Product>> getProducts({
    String? category,
    String? brand,
    int? minPrice,
    int? maxPrice,
    String query = '',
  }) async {
    final page = await fetchProducts(
      category: category,
      brand: brand,
      minPrice: minPrice,
      maxPrice: maxPrice,
      limit: 100,
    );
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return page.items;
    return page.items
        .where(
          (product) => <String>[
            product.title,
            product.brand,
            product.mallName,
          ].any((value) => value.toLowerCase().contains(normalized)),
        )
        .toList(growable: false);
  }

  /// UI cache lookup. The current API contract has no `/products/{id}` route,
  /// so a real implementation should resolve this from fetched list pages.
  Future<Product?> getProductById(String id);
}

class MockProductRepository extends ProductRepository {
  MockProductRepository({
    this.latency = const Duration(milliseconds: 140),
    List<Product> products = mockProducts,
  }) : _products = List<Product>.unmodifiable(products);

  final Duration latency;
  final List<Product> _products;

  @override
  Future<ProductPage> fetchProducts({
    String? category,
    String? brand,
    int? minPrice,
    int? maxPrice,
    int limit = 20,
    String? cursor,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final apiCategory = category == null
        ? null
        : ProductCategories.apiValueFor(category);
    final normalizedBrand = brand?.trim().toLowerCase();
    final filtered = _products
        .where((product) {
          if (apiCategory != null && product.category != apiCategory) {
            return false;
          }
          if (normalizedBrand != null &&
              normalizedBrand.isNotEmpty &&
              !product.brand.toLowerCase().contains(normalizedBrand)) {
            return false;
          }
          if (minPrice != null && product.price < minPrice) {
            return false;
          }
          if (maxPrice != null && product.price > maxPrice) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    final requestedStart = int.tryParse(cursor ?? '') ?? 0;
    final start = requestedStart.clamp(0, filtered.length);
    final pageSize = limit.clamp(1, 100);
    final end = (start + pageSize).clamp(start, filtered.length);
    final items = filtered.sublist(start, end);

    return ProductPage(
      items: List<Product>.unmodifiable(items),
      nextCursor: end < filtered.length ? end.toString() : null,
    );
  }

  @override
  Future<Product?> getProductById(String id) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }
}
