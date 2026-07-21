import 'package:flutter/foundation.dart';

import 'product.dart';

/// 계약 §10 SNS 피드 — Post / 플랫폼 스토리바.
@immutable
class PostAuthor {
  const PostAuthor({required this.id, required this.nickname});

  final String id;
  final String nickname;

  factory PostAuthor.fromJson(Map<String, dynamic> json) => PostAuthor(
        id: (json['id'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
      );
}

@immutable
class Post {
  const Post({
    required this.id,
    required this.author,
    required this.caption,
    this.beforeUrl,
    required this.afterUrl,
    this.product,
    required this.buyVotes,
    required this.skipVotes,
    this.myVote,
    this.commentCount = 0,
    required this.createdAt,
  });

  final String id;
  final PostAuthor author;
  final String caption;
  final String? beforeUrl;
  final String afterUrl;
  final Product? product;
  final int buyVotes;
  final int skipVotes;
  final String? myVote; // buy | skip | null
  final int commentCount;
  final DateTime createdAt;

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: (json['id'] ?? '').toString(),
        author: PostAuthor.fromJson(
          Map<String, dynamic>.from(json['author'] as Map),
        ),
        caption: (json['caption'] ?? '').toString(),
        beforeUrl: json['before_url']?.toString(),
        afterUrl: (json['after_url'] ?? '').toString(),
        product: json['product'] is Map
            ? Product.fromJson(Map<String, dynamic>.from(json['product'] as Map))
            : null,
        buyVotes: (json['buy_votes'] as num?)?.toInt() ?? 0,
        skipVotes: (json['skip_votes'] as num?)?.toInt() ?? 0,
        myVote: json['my_vote']?.toString(),
        commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
      );

  Post copyWith({
    int? buyVotes,
    int? skipVotes,
    Object? myVote = _unset,
    int? commentCount,
  }) {
    return Post(
      id: id,
      author: author,
      caption: caption,
      beforeUrl: beforeUrl,
      afterUrl: afterUrl,
      product: product,
      buyVotes: buyVotes ?? this.buyVotes,
      skipVotes: skipVotes ?? this.skipVotes,
      myVote: identical(myVote, _unset) ? this.myVote : myVote as String?,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
    );
  }

  static const Object _unset = Object();
}

@immutable
class FeedPage {
  const FeedPage({required this.items, this.nextCursor});

  final List<Post> items;
  final String? nextCursor;

  factory FeedPage.fromJson(Map<String, dynamic> json) => FeedPage(
        items: json['items'] is List
            ? (json['items'] as List)
                .whereType<Map>()
                .map((item) => Post.fromJson(Map<String, dynamic>.from(item)))
                .toList(growable: false)
            : const <Post>[],
        nextCursor: json['next_cursor']?.toString(),
      );
}

@immutable
class FeedPlatform {
  const FeedPlatform({required this.id, required this.name});

  final String id;
  final String name;

  factory FeedPlatform.fromJson(Map<String, dynamic> json) => FeedPlatform(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
}

@immutable
class VoteResult {
  const VoteResult({required this.post, required this.rewardCredits});

  final Post post;
  final int rewardCredits;
}


@immutable
class PostComment {
  const PostComment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final PostAuthor author;
  final String content;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: (json['id'] ?? '').toString(),
        author: PostAuthor.fromJson(
          Map<String, dynamic>.from(json['author'] as Map),
        ),
        content: (json['content'] ?? '').toString(),
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
      );
}
