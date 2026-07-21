import '../mock/mock_products.dart';
import '../models/post.dart';

/// 계약 §10: GET /platforms, GET /feed, POST /posts, POST /posts/{id}/vote
abstract class PostRepository {
  Future<List<FeedPlatform>> fetchPlatforms();

  Future<FeedPage> fetchFeed({
    String sort = 'hot',
    int limit = 20,
    String? cursor,
  });

  /// result_id가 있으면 after/product는 서버가 결과에서 자동 결정.
  Future<Post> createPost({
    String? resultId,
    String? productId,
    String caption = '',
    String? beforeUrl,
    String? afterUrl,
  });

  /// 재투표 시 선택 변경, 같은 선택은 멱등. 타인 게시물 신규 투표는 +1 크레딧(하루 3회).
  Future<VoteResult> vote({required String postId, required String choice});

  Future<List<PostComment>> fetchComments(String postId);

  Future<PostComment> addComment({
    required String postId,
    required String content,
  });
}

class MockPostRepository implements PostRepository {
  MockPostRepository() {
    final now = DateTime.now().toUtc();
    _posts.addAll([
      Post(
        id: 'po_mock_1',
        author: const PostAuthor(id: 'u_2', nickname: '미나'),
        caption: '여름 바다 갈 때 이거 어때요? 🌊',
        afterUrl: 'assets/images/mock/try_on_result_01.png',
        product: mockProducts.first,
        buyVotes: 14,
        skipVotes: 3,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'po_mock_2',
        author: const PostAuthor(id: 'u_3', nickname: '준호'),
        caption: '출근룩으로 괜찮을까요?',
        afterUrl: 'assets/images/mock/try_on_result_01.png',
        product: mockProducts.length > 3 ? mockProducts[3] : null,
        buyVotes: 8,
        skipVotes: 6,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ]);
  }

  final List<Post> _posts = [];
  final Map<String, List<PostComment>> _comments = {};
  int _sequence = 2;
  int _commentSequence = 0;
  int _rewardsToday = 0;

  @override
  Future<List<FeedPlatform>> fetchPlatforms() async => const [
        FeedPlatform(id: 'pt_1', name: 'OTFIT 파트너몰'),
      ];

  @override
  Future<FeedPage> fetchFeed({
    String sort = 'hot',
    int limit = 20,
    String? cursor,
  }) async {
    final sorted = [..._posts];
    if (sort == 'new') {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      sorted.sort(
        (a, b) => (b.buyVotes + b.skipVotes).compareTo(a.buyVotes + a.skipVotes),
      );
    }
    return FeedPage(items: sorted.take(limit).toList(growable: false));
  }

  @override
  Future<Post> createPost({
    String? resultId,
    String? productId,
    String caption = '',
    String? beforeUrl,
    String? afterUrl,
  }) async {
    final post = Post(
      id: 'po_mock_${++_sequence}',
      author: const PostAuthor(id: 'u_mock_1', nickname: '오핏'),
      caption: caption,
      beforeUrl: beforeUrl,
      afterUrl: afterUrl ?? 'assets/images/mock/try_on_result_01.png',
      product: productId == null ? mockProducts.first : mockProductById(productId),
      buyVotes: 0,
      skipVotes: 0,
      createdAt: DateTime.now().toUtc(),
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<VoteResult> vote({
    required String postId,
    required String choice,
  }) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    final post = _posts[index];
    if (post.myVote == choice) {
      return VoteResult(post: post, rewardCredits: 0);
    }
    final isNewVote = post.myVote == null;
    final updated = post.copyWith(
      buyVotes: post.buyVotes +
          (choice == 'buy' ? 1 : 0) -
          (post.myVote == 'buy' ? 1 : 0),
      skipVotes: post.skipVotes +
          (choice == 'skip' ? 1 : 0) -
          (post.myVote == 'skip' ? 1 : 0),
      myVote: choice,
    );
    _posts[index] = updated;
    final reward = isNewVote && _rewardsToday < 3 ? 1 : 0;
    _rewardsToday += reward;
    return VoteResult(post: updated, rewardCredits: reward);
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async =>
      List.unmodifiable(_comments[postId] ?? const <PostComment>[]);

  @override
  Future<PostComment> addComment({
    required String postId,
    required String content,
  }) async {
    final comment = PostComment(
      id: 'cm_mock_${++_commentSequence}',
      author: const PostAuthor(id: 'u_mock_1', nickname: '오핏'),
      content: content,
      createdAt: DateTime.now().toUtc(),
    );
    _comments.putIfAbsent(postId, () => []).add(comment);
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] =
          _posts[index].copyWith(commentCount: _posts[index].commentCount + 1);
    }
    return comment;
  }
}

