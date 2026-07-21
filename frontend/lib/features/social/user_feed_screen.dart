import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/post.dart';
import '../../models/product.dart';
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

  /// 새 게시물: 상품(옷)을 골라 등록
  Future<void> _createPost(BuildContext context, WidgetRef ref) async {
    final products = await ref.read(productsProvider.future);
    if (!context.mounted) return;
    Product? selected;
    final captionController = TextEditingController();
    final published = await showModalBottomSheet<bool>(
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
              Text('새 게시물 — 옷 등록',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final isSelected = selected?.id == product.id;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selected = product),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryPurple
                                    : AppColors.divider,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: product.displayImage.startsWith('assets/')
                                ? Image.asset(product.displayImage,
                                    fit: BoxFit.cover)
                                : Image.network(product.displayImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                        Icons.checkroom_rounded)),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 76,
                            child: Text(
                              product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(sheetContext).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
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
                onPressed: () {
                  if (selected == null) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('옷을 먼저 선택해 주세요.')),
                    );
                    return;
                  }
                  Navigator.of(sheetContext).pop(true);
                },
                child: const Text('게시하기'),
              ),
            ],
          ),
        ),
      ),
    );
    if (published != true || selected == null || !context.mounted) return;
    try {
      await ref.read(postRepositoryProvider).createPost(
            productId: selected!.id,
            caption: captionController.text.trim(),
            afterUrl: selected!.imageUrl,
          );
      ref.invalidate(userPostsProvider(userId));
      ref.invalidate(userProfileProvider(userId));
      ref.invalidate(feedProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('게시했어요!')));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('게시 실패: $error')));
      }
    }
  }

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
                                  child: post.afterUrl.startsWith('assets/')
                                      ? Image.asset(post.afterUrl,
                                          fit: BoxFit.cover)
                                      : Image.network(
                                          post.afterUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                            color: AppColors.surfaceMuted,
                                            child: Icon(Icons
                                                .broken_image_outlined),
                                          ),
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onFollowTap});

  final UserProfile profile;
  final VoidCallback onFollowTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
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
                    fontSize: 26,
                  ),
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CountColumn(count: profile.postCount, label: '게시물'),
                    _CountColumn(count: profile.followerCount, label: '팔로워'),
                    _CountColumn(count: profile.followingCount, label: '팔로잉'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              profile.nickname,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!profile.isMe) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: profile.isFollowing
                  ? OutlinedButton(
                      onPressed: onFollowTap, child: const Text('팔로잉 ✓'))
                  : FilledButton(
                      onPressed: onFollowTap, child: const Text('팔로우')),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountColumn extends StatelessWidget {
  const _CountColumn({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('$count',
            style: textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900)),
        Text(label,
            style:
                textTheme.labelSmall?.copyWith(color: AppColors.secondaryText)),
      ],
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
                if (widget.isMine)
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    onPressed: _delete,
                  ),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: _post.afterUrl.startsWith('assets/')
                              ? Image.asset(_post.afterUrl, fit: BoxFit.cover)
                              : Image.network(
                                  _post.afterUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: AppColors.surfaceMuted,
                                    child:
                                        Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                        ),
                      ),
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
