import '../mock/mock_products.dart';
import '../models/fitting_result.dart' show Photo;
import '../models/mypage.dart';
import '../models/product.dart';

/// 계약 §11 마이페이지: 내 피팅 기록 / 내 사진 / 찜한 상품.
abstract class MyPageRepository {
  Future<List<MyFitting>> fetchMyFittings({int limit = 30});

  Future<List<Photo>> fetchMyPhotos({int limit = 30});

  Future<List<Product>> fetchFavorites();

  Future<void> addFavorite(String productId);

  Future<void> removeFavorite(String productId);
}

class MockMyPageRepository implements MyPageRepository {
  final Set<String> _favoriteIds = {
    for (final product in mockProducts)
      if (product.isFavorite) product.id,
  };

  @override
  Future<List<MyFitting>> fetchMyFittings({int limit = 30}) async =>
      const <MyFitting>[];

  @override
  Future<List<Photo>> fetchMyPhotos({int limit = 30}) async => const <Photo>[];

  @override
  Future<List<Product>> fetchFavorites() async => mockProducts
      .where((product) => _favoriteIds.contains(product.id))
      .toList(growable: false);

  @override
  Future<void> addFavorite(String productId) async =>
      _favoriteIds.add(productId);

  @override
  Future<void> removeFavorite(String productId) async =>
      _favoriteIds.remove(productId);
}
