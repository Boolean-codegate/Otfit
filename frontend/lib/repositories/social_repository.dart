import '../models/fitting_result.dart' show User;
import '../models/post.dart';
import '../models/social.dart';

/// 계약 §12: 유저 검색/프로필/게시물 그리드/팔로우/게시물 삭제.
abstract class SocialRepository {
  Future<List<UserSummary>> searchUsers(String query);

  /// [userId]에 'me' 별칭 허용.
  Future<UserProfile> fetchProfile(String userId);

  Future<List<Post>> fetchUserPosts(String userId, {int limit = 30});

  Future<void> follow(String userId);

  Future<void> unfollow(String userId);

  Future<void> deletePost(String postId);

  Future<List<UserSummary>> fetchFollowers(String userId);

  Future<List<UserSummary>> fetchFollowing(String userId);

  /// PATCH /me — 닉네임/소개글 수정.
  Future<User> updateMe({String? nickname, String? bio});
}

class MockSocialRepository implements SocialRepository {
  bool _following = false;

  @override
  Future<List<UserSummary>> searchUsers(String query) async => const [
        UserSummary(id: 'u_2', nickname: '미나'),
        UserSummary(id: 'u_3', nickname: '준호'),
      ];

  @override
  Future<UserProfile> fetchProfile(String userId) async => UserProfile(
        id: userId,
        nickname: userId == 'me' || userId == 'u_mock_1' ? '오핏' : '미나',
        postCount: 2,
        followerCount: _following ? 1 : 0,
        followingCount: 3,
        isFollowing: _following,
        isMe: userId == 'me' || userId == 'u_mock_1',
      );

  @override
  Future<List<Post>> fetchUserPosts(String userId, {int limit = 30}) async =>
      const <Post>[];

  @override
  Future<void> follow(String userId) async => _following = true;

  @override
  Future<void> unfollow(String userId) async => _following = false;

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<List<UserSummary>> fetchFollowers(String userId) async => const [];

  @override
  Future<List<UserSummary>> fetchFollowing(String userId) async => const [];

  @override
  Future<User> updateMe({String? nickname, String? bio}) async => User(
        id: 'u_mock_1',
        email: 'mock@otfit.local',
        nickname: nickname ?? '오핏',
        bio: bio ?? '',
        creditBalance: 30,
        isPremium: false,
        createdAt: DateTime.now().toUtc(),
      );
}
