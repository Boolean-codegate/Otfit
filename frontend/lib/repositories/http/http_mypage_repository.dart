import '../../core/network/api_client.dart';
import '../../models/fitting_result.dart' show Photo;
import '../../models/mypage.dart';
import '../../models/product.dart';
import '../mypage_repository.dart';

class HttpMyPageRepository implements MyPageRepository {
  HttpMyPageRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<MyFitting>> fetchMyFittings({int limit = 30}) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/me/fittings',
        queryParameters: <String, dynamic>{'limit': limit},
      );
      final items = response.data?['items'];
      if (items is! List) return const <MyFitting>[];
      return items
          .whereType<Map>()
          .map((item) => MyFitting.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<List<Photo>> fetchMyPhotos({int limit = 30}) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/me/photos',
        queryParameters: <String, dynamic>{'limit': limit},
      );
      final items = response.data?['items'];
      if (items is! List) return const <Photo>[];
      return items
          .whereType<Map>()
          .map((item) => Photo.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<List<Product>> fetchFavorites() {
    return guardApi(() async {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/me/favorites');
      final items = response.data?['items'];
      if (items is! List) return const <Product>[];
      return items
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<void> addFavorite(String productId) {
    return guardApi(() async {
      await _client.dio.put<Map<String, dynamic>>('/me/favorites/$productId');
    });
  }

  @override
  Future<void> removeFavorite(String productId) {
    return guardApi(() async {
      await _client.dio.delete<void>('/me/favorites/$productId');
    });
  }
}
