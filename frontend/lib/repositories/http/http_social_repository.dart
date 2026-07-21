import '../../core/network/api_client.dart';
import '../../models/fitting_result.dart' show User;
import '../../models/post.dart';
import '../../models/social.dart';
import '../social_repository.dart';

class HttpSocialRepository implements SocialRepository {
  HttpSocialRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<UserSummary>> searchUsers(String query) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/users/search',
        queryParameters: <String, dynamic>{'q': query},
      );
      final items = response.data?['items'];
      if (items is! List) return const <UserSummary>[];
      return items
          .whereType<Map>()
          .map((item) => UserSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<UserProfile> fetchProfile(String userId) {
    return guardApi(() async {
      final response = await _client.dio
          .get<Map<String, dynamic>>('/users/$userId/profile');
      return UserProfile.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<List<Post>> fetchUserPosts(String userId, {int limit = 30}) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/users/$userId/posts',
        queryParameters: <String, dynamic>{'limit': limit},
      );
      final items = response.data?['items'];
      if (items is! List) return const <Post>[];
      return items
          .whereType<Map>()
          .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<void> follow(String userId) {
    return guardApi(() async {
      await _client.dio.put<Map<String, dynamic>>('/users/$userId/follow');
    });
  }

  @override
  Future<void> unfollow(String userId) {
    return guardApi(() async {
      await _client.dio.delete<void>('/users/$userId/follow');
    });
  }

  @override
  Future<void> deletePost(String postId) {
    return guardApi(() async {
      await _client.dio.delete<void>('/posts/$postId');
    });
  }

  Future<List<UserSummary>> _userList(String path) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(path);
      final items = response.data?['items'];
      if (items is! List) return const <UserSummary>[];
      return items
          .whereType<Map>()
          .map((item) => UserSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<List<UserSummary>> fetchFollowers(String userId) =>
      _userList('/users/$userId/followers');

  @override
  Future<List<UserSummary>> fetchFollowing(String userId) =>
      _userList('/users/$userId/following');

  @override
  Future<User> updateMe({String? nickname, String? bio}) {
    return guardApi(() async {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/me',
        data: <String, dynamic>{'nickname': ?nickname, 'bio': ?bio},
      );
      return User.fromJson(response.data ?? const <String, dynamic>{});
    });
  }
}
