import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/post.dart';
import '../../core/widgets/before_after_image.dart';
import 'publish_fitting_sheet.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';
import '../feed/feed_screen.dart' show CommentsSheet;

/// 인스타그램형 유저 피드 (계약 §12).
/// 헤더(게시물/팔로워/팔로잉 + 팔로우 버튼) + 3열 그리드.
/// 내 피드(userId='me')는 새 게시물 등록(옷 등록)·삭제 관리 가능.
class UserFeedScreen extends ConsumerWidget {
  const UserFeedScreen({super.key, required this.userId});

  final String userId;

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final repository = ref.read(socialRepositoryProvider);
    try {
      profile.isFollowing
          ? await repository.unfollow(profile.id)
          : await repository.follow(profile.id);
      ref.invalidate(userProfileProvider(userId));
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('실패: $error')));
      }
    }
  }

  /// 새 게시물: 내 피팅 결과(내 사진)만 게시할 수 있다 — 공용 시트 재사용.
  Future<void> _createPost(BuildContext context, WidgetRef ref) =>
      showPublishFittingSheet(context, ref, feedUserId: userId);

  void _openPost(BuildContext context, WidgetRef ref, Post post, bool isMe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostDetailSheet(post: post, isMine: isMe, userId: userId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));
    final posts = ref.watch(userPostsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(profile.value?.nickname ?? '피드'),
        actions: [
          if (profile.value?.isMe == true) ...[
            IconButton(
              tooltip: '새 게시물',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => _createPost(context, ref),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userProfileProvider(userId));
            ref.invalidate(userPostsProvider(userId));
          },
          child: ResponsiveContent(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: profile.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(30),
                      child: Center(child: Text('프로필을 불러오지 못했어요\n$error')),
                    ),
                    data: (info) => _ProfileHeader(
                      profile: info,
                      onFollowTap: () => _toggleFollow(context, ref, info),
                    ),
                  ),
                ),
                posts.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, _) => SliverToBoxAdapter(
                    child: Center(child: Text('게시물을 불러오지 못했어요\n$error')),
                  ),
                  data: (items) => items.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                const Icon(Icons.grid_on_rounded,
                                    size: 44, color: AppColors.disabled),
                                const SizedBox(height: 10),
                                const Text('아직 게시물이 없어요'),
                                if (profile.value?.isMe == true) ...[
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () => _createPost(context, ref),
                                    child: const Text('첫 게시물 올리기'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(2, 2, 2, 96),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 2,
                              crossAxisSpacing: 2,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final post = items[index];
                                return GestureDetector(
                                  onTap: () => _openPost(context, ref, post,
                                      profile.value?.isMe == true),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      post.afterUrl.startsWith('assets/')
                                          ? Image.asset(post.afterUrl,
                                              fit: BoxFit.cover)
                                          : Image.network(
                                              post.afterUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const ColoredBox(
                                                color:
                                                    AppColors.surfaceMuted,
                                                child: Icon(Icons
                                                    .broken_image_outlined),
                                              ),
                                            ),
                                      if (post.beforeUrl != null)
                                        Positioned(
                                          top: 5,
                                          left: 5,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient:
                                                  AppColors.primaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'B→A',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                              childCount: items.length,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile, required this.onFollowTap});

  final UserProfile profile;
  final VoidCallback onFollowTap;

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final nicknameController = TextEditingController(text: profile.nickname);
    final bioController = TextEditingController(text: profile.bio);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('프로필 편집',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextField(
              controller: nicknameController,
              maxLength: 50,
              decoration: const InputDecoration(labelText: '닉네임'),
            ),
            TextField(
              controller: bioController,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '소개글',
                hintText: '나의 스타일을 소개해보세요 ✨',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !context.mounted) return;
    try {
      await ref.read(socialRepositoryProvider).updateMe(
            nickname: nicknameController.text.trim(),
            bio: bioController.text.trim(),
          );
      ref.invalidate(userProfileProvider(profile.isMe ? 'me' : profile.id));
      await ref.read(authSessionProvider.notifier).refreshMe();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('저장 실패: $error')));
      }
    }
  }

  void _showFollowList(BuildContext context, {required bool followers}) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _FollowListSheet(
        userId: profile.isMe ? 'me' : profile.id,
        followers: followers,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.softGradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    profile.nickname.characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.nickname,
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        profile.bio.isEmpty
                            ? (profile.isMe
                                ? '소개글을 추가해보세요'
                                : '비포 → 애프터로 변신 중')
                            : profile.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.secondaryText),
                      ),
                    ],
                  ),
                ),
                if (profile.isMe)
                  IconButton(
                    tooltip: '프로필 편집',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _editProfile(context, ref),
                  )
                else
                  profile.isFollowing
                      ? OutlinedButton(
                          onPressed: onFollowTap,
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('팔로잉 ✓'),
                        )
                      : FilledButton(
                          onPressed: onFollowTap,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('팔로우'),
                        ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatChip(
                  emoji: '📸',
                  label: '게시물 ${profile.postCount}개',
                ),
                _StatChip(
                  emoji: '💜',
                  label: '팔로워 ${profile.followerCount}',
                  onTap: () => _showFollowList(context, followers: true),
                ),
                _StatChip(
                  emoji: '👀',
                  label: '팔로잉 ${profile.followingCount}',
                  onTap: () => _showFollowList(context, followers: false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.emoji,
    required this.label,
    this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            '$emoji $label',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.mainText,
            ),
          ),
        ),
      ),
    );
  }
}

/// 팔로워/팔로잉 목록 — 탭하면 그 유저의 변신 피드로
class _FollowListSheet extends ConsumerWidget {
  const _FollowListSheet({required this.userId, required this.followers});

  final String userId;
  final bool followers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(socialRepositoryProvider);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.55,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                Text(followers ? '팔로워' : '팔로잉',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: followers
                  ? repository.fetchFollowers(userId)
                  : repository.fetchFollowing(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data ?? const <UserSummary>[];
                if (users.isEmpty) {
                  return Center(
                      child: Text(followers ? '아직 팔로워가 없어요' : '아직 팔로잉이 없어요'));
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.lightPurple,
                        child: Text(
                          user.nickname.characters.first,
                          style: const TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(user.nickname),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/users/${user.id}');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 그리드 탭 → 게시물 상세 (투표·댓글·삭제)
class _PostDetailSheet extends ConsumerStatefulWidget {
  const _PostDetailSheet({
    required this.post,
    required this.isMine,
    required this.userId,
  });

  final Post post;
  final bool isMine;
  final String userId;

  @override
  ConsumerState<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends ConsumerState<_PostDetailSheet> {
  late Post _post = widget.post;

  Future<void> _vote(String choice) async {
    try {
      final result = await ref
          .read(postRepositoryProvider)
          .vote(postId: _post.id, choice: choice);
      setState(() => _post = result.post);
      ref.invalidate(userPostsProvider(widget.userId));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('투표 실패: $error')));
      }
    }
  }

  /// 상세 안에서 바로 수정 — 캡션 + 비포 공개 여부.
  Future<void> _edit() async {
    final captionController = TextEditingController(text: _post.caption);
    final hadBefore = _post.beforeUrl != null;
    var includeBefore = hadBefore;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('게시물 수정하기',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: includeBefore,
                onChanged: (value) =>
                    setSheetState(() => includeBefore = value),
                title: const Text('비포 사진 함께 공개'),
                subtitle: Text(
                  '비포 → 애프터 변신을 보여줘요 ✨',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ),
              TextField(
                controller: captionController,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '이 옷 어때요? 살까 말까 물어보세요 🙋',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('수정하기'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      final updated = await ref.read(postRepositoryProvider).updatePost(
            postId: _post.id,
            caption: captionController.text.trim(),
            includeBefore: includeBefore && !hadBefore,
            removeBefore: !includeBefore && hadBefore,
          );
      setState(() => _post = updated);
      ref.invalidate(userPostsProvider(widget.userId));
      ref.invalidate(feedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시물을 수정했어요!')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('수정 실패: $error')));
      }
    }
  }

  /// 게시할 때 비포를 안 붙였어도, 연결된 피팅 결과의 원본 사진으로 나중에 추가할 수 있다.
  Future<void> _addBefore() async {
    try {
      final updated = await ref
          .read(postRepositoryProvider)
          .updatePost(postId: _post.id, includeBefore: true);
      setState(() => _post = updated);
      ref.invalidate(userPostsProvider(widget.userId));
      ref.invalidate(feedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('비포 사진을 추가했어요 ✨')));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('비포 추가 실패: $error')));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: const Text('이 게시물을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(socialRepositoryProvider).deletePost(_post.id);
      ref.invalidate(userPostsProvider(widget.userId));
      ref.invalidate(userProfileProvider(widget.userId));
      ref.invalidate(feedProvider);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Text(_post.author.nickname,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (widget.isMine) ...[
                  IconButton(
                    tooltip: '수정',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _edit,
                  ),
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    onPressed: _delete,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BeforeAfterImage(
                        afterUrl: _post.afterUrl,
                        beforeUrl: _post.beforeUrl,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      if (widget.isMine && _post.beforeUrl == null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addBefore,
                          icon: const Icon(Icons.compare_arrows_rounded,
                              size: 16),
                          label: const Text('비포 사진 추가'),
                        ),
                      ],
                      if (_post.caption.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(_post.caption, style: textTheme.bodyMedium),
                      ],
                      if (_post.product != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push('/shop/product/${_post.product!.id}');
                          },
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: Text(
                            '${_post.product!.title} · ${_post.product!.price}원',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _vote('buy'),
                              style: _post.myVote == 'buy'
                                  ? OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.lightPurple)
                                  : null,
                              child: Text('살래요 👍 ${_post.buyVotes}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _vote('skip'),
                              style: _post.myVote == 'skip'
                                  ? OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.lightPurple)
                                  : null,
                              child: Text('글쎄요 🤔 ${_post.skipVotes}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CommentsSheet(postId: _post.id),
                        ),
                        icon: const Icon(Icons.mode_comment_outlined, size: 16),
                        label: Text(_post.commentCount == 0
                            ? '첫 댓글을 남겨보세요'
                            : '댓글 ${_post.commentCount}개 보기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
