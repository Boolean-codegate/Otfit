import '../../core/network/api_client.dart';
import '../../models/post.dart';
import '../post_repository.dart';

/// 계약 §10 SNS 피드 HTTP 구현.
class HttpPostRepository implements PostRepository {
  HttpPostRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<FeedPlatform>> fetchPlatforms() {
    return guardApi(() async {
      final response = await _client.dio.get<List<dynamic>>('/platforms');
      return (response.data ?? const [])
          .whereType<Map>()
          .map((item) => FeedPlatform.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<FeedPage> fetchFeed({
    String sort = 'hot',
    int limit = 20,
    String? cursor,
  }) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/feed',
        queryParameters: <String, dynamic>{
          'sort': sort,
          'limit': limit,
          'cursor': ?cursor,
        },
      );
      return FeedPage.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<Post> createPost({
    String? resultId,
    String? productId,
    String caption = '',
    String? beforeUrl,
    String? afterUrl,
  }) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/posts',
        data: <String, dynamic>{
          'result_id': ?resultId,
          'product_id': ?productId,
          'caption': caption,
          'before_url': ?beforeUrl,
          'after_url': ?afterUrl,
        },
      );
      return Post.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<VoteResult> vote({required String postId, required String choice}) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/posts/$postId/vote',
        data: <String, dynamic>{'choice': choice},
      );
      final data = response.data ?? const <String, dynamic>{};
      return VoteResult(
        post: Post.fromJson(Map<String, dynamic>.from(data['post'] as Map)),
        rewardCredits: (data['reward_credits'] as num?)?.toInt() ?? 0,
      );
    });
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) {
    return guardApi(() async {
      final response = await _client.dio
          .get<Map<String, dynamic>>('/posts/$postId/comments');
      final items = response.data?['items'];
      if (items is! List) return const <PostComment>[];
      return items
          .whereType<Map>()
          .map((item) => PostComment.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    });
  }

  @override
  Future<PostComment> addComment({
    required String postId,
    required String content,
  }) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/posts/$postId/comments',
        data: <String, dynamic>{'content': content},
      );
      return PostComment.fromJson(response.data ?? const <String, dynamic>{});
    });
  }
}
