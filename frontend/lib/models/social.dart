import 'package:flutter/foundation.dart';

/// 계약 §12 소셜 프로필.
@immutable
class UserSummary {
  const UserSummary({required this.id, required this.nickname});

  final String id;
  final String nickname;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: (json['id'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
      );
}

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    this.bio = '',
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowing,
    required this.isMe,
  });

  final String id;
  final String nickname;
  final String bio;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final bool isMe;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: (json['id'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
        bio: (json['bio'] ?? '').toString(),
        postCount: (json['post_count'] as num?)?.toInt() ?? 0,
        followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
        followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
        isFollowing: json['is_following'] == true,
        isMe: json['is_me'] == true,
      );
}
